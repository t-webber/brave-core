// Copyright (c) 2025 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#include "brave/components/ai_chat/content/browser/full_screenshotter.h"

#include <memory>

#include "base/test/test_future.h"
#include "chrome/test/base/chrome_render_view_host_test_harness.h"
#include "components/paint_preview/common/mojom/paint_preview_recorder.mojom.h"
#include "components/services/paint_preview_compositor/public/mojom/paint_preview_compositor.mojom.h"
#include "content/public/test/navigation_simulator.h"
#include "mojo/public/cpp/bindings/associated_receiver.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "third_party/blink/public/common/associated_interfaces/associated_interface_provider.h"

namespace ai_chat {

namespace {

class MockPaintPreviewRecorder
    : public paint_preview::mojom::PaintPreviewRecorder {
 public:
  MockPaintPreviewRecorder() = default;
  ~MockPaintPreviewRecorder() override = default;

  MockPaintPreviewRecorder(const MockPaintPreviewRecorder&) = delete;
  MockPaintPreviewRecorder& operator=(const MockPaintPreviewRecorder&) = delete;

  void CapturePaintPreview(
      paint_preview::mojom::PaintPreviewCaptureParamsPtr params,
      paint_preview::mojom::PaintPreviewRecorder::CapturePaintPreviewCallback
          callback) override {
    std::move(callback).Run(status_, std::move(response_));
  }

  void SetResponse(
      paint_preview::mojom::PaintPreviewStatus status,
      paint_preview::mojom::PaintPreviewCaptureResponsePtr&& response) {
    status_ = status;
    response_ = std::move(response);
  }

  void BindRequest(mojo::ScopedInterfaceEndpointHandle handle) {
    binding_.reset();
    binding_.Bind(
        mojo::PendingAssociatedReceiver<
            paint_preview::mojom::PaintPreviewRecorder>(std::move(handle)));
  }

 private:
  paint_preview::mojom::PaintPreviewStatus status_;
  paint_preview::mojom::PaintPreviewCaptureResponsePtr response_;
  mojo::AssociatedReceiver<paint_preview::mojom::PaintPreviewRecorder> binding_{
      this};
};

class MockPaintPreviewCompositorClient
    : public paint_preview::PaintPreviewCompositorClient {
 public:
  explicit MockPaintPreviewCompositorClient(
      scoped_refptr<base::SingleThreadTaskRunner> task_runner)
      : response_status_(paint_preview::mojom::PaintPreviewCompositor::
                             BeginCompositeStatus::kSuccess),
        token_(base::UnguessableToken::Create()),
        task_runner_(task_runner) {}
  ~MockPaintPreviewCompositorClient() override = default;

  MockPaintPreviewCompositorClient(const MockPaintPreviewCompositorClient&) =
      delete;
  MockPaintPreviewCompositorClient& operator=(
      const MockPaintPreviewCompositorClient&) = delete;

  const std::optional<base::UnguessableToken>& Token() const override {
    return token_;
  }

  void SetDisconnectHandler(base::OnceClosure closure) override {
    disconnect_handler_ = std::move(closure);
  }

  void BeginSeparatedFrameComposite(
      paint_preview::mojom::PaintPreviewBeginCompositeRequestPtr request,
      paint_preview::mojom::PaintPreviewCompositor::
          BeginSeparatedFrameCompositeCallback callback) override {
    auto response =
        paint_preview::mojom::PaintPreviewBeginCompositeResponse::New();
    response->root_frame_guid = base::UnguessableToken::Create();
    task_runner_->PostTask(FROM_HERE,
                           base::BindOnce(std::move(callback), response_status_,
                                          std::move(response)));
  }

  void BitmapForSeparatedFrame(
      const base::UnguessableToken& frame_guid,
      const gfx::Rect& clip_rect,
      float scale_factor,
      paint_preview::mojom::PaintPreviewCompositor::
          BitmapForSeparatedFrameCallback callback,
      bool run_task_on_default_task_runner = true) override {
    SkBitmap bitmap;
    bitmap.allocPixels(
        SkImageInfo::MakeN32Premul(clip_rect.width(), clip_rect.height()));
    task_runner_->PostDelayedTask(
        FROM_HERE,
        base::BindOnce(std::move(callback),
                       paint_preview::mojom::PaintPreviewCompositor::
                           BitmapStatus::kSuccess,
                       bitmap),
        base::Seconds(1));
  }

  void BeginMainFrameComposite(
      paint_preview::mojom::PaintPreviewBeginCompositeRequestPtr request,
      paint_preview::mojom::PaintPreviewCompositor::
          BeginMainFrameCompositeCallback callback) override {
    auto response =
        paint_preview::mojom::PaintPreviewBeginCompositeResponse::New();
    response->root_frame_guid = base::UnguessableToken::Create();
    LOG(ERROR) << static_cast<int>(response_status_);
    task_runner_->PostTask(FROM_HERE,
                           base::BindOnce(std::move(callback), response_status_,
                                          std::move(response)));
  }

  void BitmapForMainFrame(
      const gfx::Rect& clip_rect,
      float scale_factor,
      paint_preview::mojom::PaintPreviewCompositor::BitmapForMainFrameCallback
          callback,
      bool run_task_on_default_task_runner = true) override {
    SkBitmap bitmap;
    bitmap.allocPixels(
        SkImageInfo::MakeN32Premul(clip_rect.width(), clip_rect.height()));
    task_runner_->PostDelayedTask(
        FROM_HERE,
        base::BindOnce(std::move(callback),
                       paint_preview::mojom::PaintPreviewCompositor::
                           BitmapStatus::kSuccess,
                       bitmap),
        base::Seconds(1));
  }

  void SetRootFrameUrl(const GURL& url) override {
    // no-op
  }

  void SetBeginSeparatedFrameResponseStatus(
      paint_preview::mojom::PaintPreviewCompositor::BeginCompositeStatus
          status) {
    response_status_ = status;
  }

  void Disconnect() {
    if (disconnect_handler_) {
      std::move(disconnect_handler_).Run();
    }
  }

 private:
  paint_preview::mojom::PaintPreviewCompositor::BeginCompositeStatus
      response_status_;
  std::optional<base::UnguessableToken> token_;
  base::OnceClosure disconnect_handler_;
  scoped_refptr<base::SingleThreadTaskRunner> task_runner_;
};

class MockPaintPreviewCompositorService
    : public paint_preview::PaintPreviewCompositorService {
 public:
  explicit MockPaintPreviewCompositorService(
      scoped_refptr<base::SingleThreadTaskRunner> task_runner)
      : task_runner_(task_runner), timeout_(false) {}
  ~MockPaintPreviewCompositorService() override = default;

  MockPaintPreviewCompositorService(const MockPaintPreviewCompositorService&) =
      delete;
  MockPaintPreviewCompositorService& operator=(
      const MockPaintPreviewCompositorService&) = delete;

  std::unique_ptr<paint_preview::PaintPreviewCompositorClient,
                  base::OnTaskRunnerDeleter>
  CreateCompositor(base::OnceClosure connected_closure) override {
    task_runner_->PostTask(
        FROM_HERE, timeout_ ? base::DoNothing() : std::move(connected_closure));
    return std::unique_ptr<MockPaintPreviewCompositorClient,
                           base::OnTaskRunnerDeleter>(
        new MockPaintPreviewCompositorClient(task_runner_),
        base::OnTaskRunnerDeleter(task_runner_));
  }

  void OnMemoryPressure(base::MemoryPressureListener::MemoryPressureLevel
                            memory_pressure_level) override {
    // no-op.
  }

  void SetTimeout() { timeout_ = true; }

  bool HasActiveClients() const override { NOTREACHED(); }

  void SetDisconnectHandler(base::OnceClosure disconnect_handler) override {
    disconnect_handler_ = std::move(disconnect_handler);
  }

  void Disconnect() {
    if (disconnect_handler_) {
      std::move(disconnect_handler_).Run();
    }
  }

 private:
  base::OnceClosure disconnect_handler_;
  scoped_refptr<base::SingleThreadTaskRunner> task_runner_;
  bool timeout_;
};

MockPaintPreviewCompositorClient* AsMockClient(
    paint_preview::PaintPreviewCompositorClient* client) {
  return static_cast<MockPaintPreviewCompositorClient*>(client);
}

#if 0
MockPaintPreviewCompositorService* AsMockService(
    paint_preview::PaintPreviewCompositorService* service) {
  return static_cast<MockPaintPreviewCompositorService*>(service);
}
#endif

}  // namespace

class FullScreenshotterTest : public ChromeRenderViewHostTestHarness {
 public:
  FullScreenshotterTest() = default;
  ~FullScreenshotterTest() override = default;

  FullScreenshotterTest(const FullScreenshotterTest&) = delete;
  FullScreenshotterTest& operator=(const FullScreenshotterTest&) = delete;

 protected:
  void SetUp() override {
    ChromeRenderViewHostTestHarness::SetUp();
    NavigateAndCommit(GURL("https://brave.com/"),
                      ui::PageTransition::PAGE_TRANSITION_FIRST);
    full_screenshotter_ = std::make_unique<FullScreenshotter>();
  }

  FullScreenshotter* full_screenshotter() { return full_screenshotter_.get(); }

  void OverrideInterface(MockPaintPreviewRecorder* recorder) {
    blink::AssociatedInterfaceProvider* remote_interfaces =
        web_contents()->GetPrimaryMainFrame()->GetRemoteAssociatedInterfaces();
    remote_interfaces->OverrideBinderForTesting(
        paint_preview::mojom::PaintPreviewRecorder::Name_,
        base::BindRepeating(&MockPaintPreviewRecorder::BindRequest,
                            base::Unretained(recorder)));
  }

  std::unique_ptr<paint_preview::PaintPreviewCompositorService,
                  base::OnTaskRunnerDeleter>
  CreateCompositorService() {
    auto task_runner = base::SingleThreadTaskRunner::GetCurrentDefault();
    return std::unique_ptr<MockPaintPreviewCompositorService,
                           base::OnTaskRunnerDeleter>(
        new MockPaintPreviewCompositorService(task_runner),
        base::OnTaskRunnerDeleter(task_runner));
  }

 private:
  std::unique_ptr<FullScreenshotter> full_screenshotter_;
};

TEST_F(FullScreenshotterTest, InvalidWebContents) {
  base::test::TestFuture<
      base::expected<std::vector<std::vector<uint8_t>>, std::string>>
      future;
  full_screenshotter()->CaptureScreenshots(nullptr, future.GetCallback());
  auto result = future.Get();
  ASSERT_FALSE(result.has_value());
  EXPECT_EQ(result.error(), "The given web contents is no longer valid");
}

TEST_F(FullScreenshotterTest, CaptureFailedAllErrorStates) {
  const paint_preview::mojom::PaintPreviewStatus kErrorStatuses[] = {
      paint_preview::mojom::PaintPreviewStatus::kAlreadyCapturing,
      paint_preview::mojom::PaintPreviewStatus::kCaptureFailed,
      paint_preview::mojom::PaintPreviewStatus::kGuidCollision,
      paint_preview::mojom::PaintPreviewStatus::kFileCreationError,
      // Covers !paint_preview::CaptureResult.capture_success
      paint_preview::mojom::PaintPreviewStatus::kPartialSuccess,
      paint_preview::mojom::PaintPreviewStatus::kFailed,
  };

  for (auto status : kErrorStatuses) {
    MockPaintPreviewRecorder recorder;
    recorder.SetResponse(
        status, paint_preview::mojom::PaintPreviewCaptureResponse::New());
    OverrideInterface(&recorder);

    base::test::TestFuture<
        base::expected<std::vector<std::vector<uint8_t>>, std::string>>
        future;
    full_screenshotter()->CaptureScreenshots(web_contents(),
                                             future.GetCallback());
    auto result = future.Take();
    ASSERT_FALSE(result.has_value());
    EXPECT_EQ(result.error(),
              base::StringPrintf(
                  "Failed to capture a screenshot (CaptureStatus=%d)",
                  static_cast<int>(paint_preview::PaintPreviewBaseService::
                                       CaptureStatus::kCaptureFailed)));
  }
  // We won't get CaptureStatus::kClientCreationFailed since we check
  // WebContents before calling CapturePaintPreview and no
  // CaptureStatus::kContentUnsupported because we don't prodvide policy.
}

TEST_F(FullScreenshotterTest, BeginMainFrameCompositeFailed) {
  auto compositor_service = CreateCompositorService();
  full_screenshotter()->InitCompositorServiceForTest(
      std::move(compositor_service));
  for (auto status : {paint_preview::mojom::PaintPreviewCompositor::
                          BeginCompositeStatus::kCompositingFailure,
                      paint_preview::mojom::PaintPreviewCompositor::
                          BeginCompositeStatus::kDeserializingFailure}) {
    AsMockClient(full_screenshotter()->GetCompositorClientForTest())
        ->SetBeginSeparatedFrameResponseStatus(status);

    MockPaintPreviewRecorder recorder;
    auto response = paint_preview::mojom::PaintPreviewCaptureResponse::New();
    response->skp.emplace(mojo_base::BigBuffer(true));
    recorder.SetResponse(paint_preview::mojom::PaintPreviewStatus::kOk,
                         std::move(response));
    OverrideInterface(&recorder);

    base::test::TestFuture<
        base::expected<std::vector<std::vector<uint8_t>>, std::string>>
        future;
    full_screenshotter()->CaptureScreenshots(web_contents(),
                                             future.GetCallback());
    auto result = future.Take();
    ASSERT_FALSE(result.has_value());
    EXPECT_EQ(result.error(), "BeginMainFrameComposite failed");
  }
}

}  // namespace ai_chat
