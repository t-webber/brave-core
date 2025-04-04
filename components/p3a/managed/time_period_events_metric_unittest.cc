/* Copyright (c) 2025 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "brave/components/p3a/managed/time_period_events_metric.h"

#include <memory>
#include <string>
#include <utility>

#include "base/json/json_reader.h"
#include "base/json/json_value_converter.h"
#include "base/test/task_environment.h"
#include "base/time/time.h"
#include "brave/components/p3a/pref_names.h"
#include "components/prefs/pref_registry_simple.h"
#include "components/prefs/testing_pref_service.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace p3a {

namespace {
constexpr char kTestHistogramName[] = "TestHistogram";
constexpr char kTestStorageKey[] = "test_storage_key";

constexpr char kTestMetricDefinitionJson[] = R"({
  "histogram_name": "TestHistogram",
  "storage_key": "test_storage_key",
  "period_days": 7,
  "buckets": [5, 10, 20]
})";

// Parses TimePeriodEventsMetricDefinition from JSON
TimePeriodEventsMetricDefinition ParseMetricDefinition(
    const std::string& json) {
  base::JSONValueConverter<TimePeriodEventsMetricDefinition> converter;
  auto dict = base::JSONReader::Read(json);
  CHECK(dict.has_value());

  TimePeriodEventsMetricDefinition definition;
  converter.Convert(*dict, &definition);

  return definition;
}
}  // namespace

class P3ATimePeriodEventsMetricUnitTest : public testing::Test {
 public:
  P3ATimePeriodEventsMetricUnitTest()
      : task_environment_(base::test::TaskEnvironment::TimeSource::MOCK_TIME) {}

  void SetUp() override {
    local_state_.registry()->RegisterDictionaryPref(
        kRemoteMetricStorageDictPref);
  }

  void CreateMetric() {
    auto definition = ParseMetricDefinition(kTestMetricDefinitionJson);

    metric_ = std::make_unique<TimePeriodEventsMetric>(
        &local_state_, std::move(definition),
        base::BindRepeating(&P3ATimePeriodEventsMetricUnitTest::OnMetricUpdated,
                            base::Unretained(this)));
  }

  void OnMetricUpdated(size_t value) {
    last_reported_value_ = value;
    report_count_++;
  }

 protected:
  base::test::TaskEnvironment task_environment_;
  TestingPrefServiceSimple local_state_;
  std::unique_ptr<TimePeriodEventsMetric> metric_;

  size_t last_reported_value_ = 0;
  int report_count_ = 0;
};

TEST_F(P3ATimePeriodEventsMetricUnitTest, ValidateDefinition) {
  auto valid_def = ParseMetricDefinition(kTestMetricDefinitionJson);
  EXPECT_TRUE(valid_def.Validate());

  // Create invalid definition with no buckets
  const auto* invalid_json1 = R"({
    "histogram_name": "TestHistogram",
    "storage_key": "test_storage_key",
    "period_days": 7,
    "buckets": []
  })";
  auto invalid_def1 = ParseMetricDefinition(invalid_json1);
  EXPECT_FALSE(invalid_def1.Validate());

  // Create invalid definition with period_days = 0
  const auto* invalid_json2 = R"({
    "histogram_name": "TestHistogram",
    "storage_key": "test_storage_key",
    "period_days": 0,
    "buckets": [5]
  })";
  auto invalid_def2 = ParseMetricDefinition(invalid_json2);
  EXPECT_FALSE(invalid_def2.Validate());

  // Create invalid definition with empty histogram_name
  const auto* invalid_json3 = R"({
    "histogram_name": "",
    "storage_key": "test_storage_key",
    "period_days": 7,
    "buckets": [5]
  })";
  auto invalid_def3 = ParseMetricDefinition(invalid_json3);
  EXPECT_FALSE(invalid_def3.Validate());

  // Create invalid definition with empty storage_key
  const auto* invalid_json4 = R"({
    "histogram_name": "TestHistogram",
    "storage_key": "",
    "period_days": 7,
    "buckets": [5]
  })";
  auto invalid_def4 = ParseMetricDefinition(invalid_json4);
  EXPECT_FALSE(invalid_def4.Validate());
}

TEST_F(P3ATimePeriodEventsMetricUnitTest, GetSourceHistogramNames) {
  CreateMetric();

  auto histogram_names = metric_->GetSourceHistogramNames();
  ASSERT_EQ(histogram_names.size(), 1u);
  EXPECT_EQ(histogram_names[0], kTestHistogramName);
}

TEST_F(P3ATimePeriodEventsMetricUnitTest, GetStorageKey) {
  CreateMetric();

  auto storage_key = metric_->GetStorageKey();
  ASSERT_TRUE(storage_key.has_value());
  EXPECT_EQ(storage_key.value(), kTestStorageKey);
}

TEST_F(P3ATimePeriodEventsMetricUnitTest, HandleHistogramChange) {
  CreateMetric();

  // Initial report on creation
  EXPECT_EQ(report_count_, 1);
  EXPECT_EQ(last_reported_value_, 0u);  // Below first bucket (5)

  // Add an event
  metric_->HandleHistogramChange(kTestHistogramName, 1);

  // Should report again
  EXPECT_EQ(report_count_, 2);
  EXPECT_EQ(last_reported_value_, 0u);  // 1 is still below first bucket (5)

  // Add more events to cross the first bucket threshold
  for (int i = 0; i < 5; i++) {
    metric_->HandleHistogramChange(kTestHistogramName, 1);
  }

  // Now we've added 6 events total, which should put us in bucket 1
  EXPECT_EQ(report_count_, 7);
  EXPECT_EQ(last_reported_value_, 1u);

  // Add more events to cross the second bucket threshold
  for (int i = 0; i < 5; i++) {
    metric_->HandleHistogramChange(kTestHistogramName, 1);
  }

  // Now we've added 11 events total, which should put us in bucket 2
  EXPECT_EQ(report_count_, 12);
  EXPECT_EQ(last_reported_value_, 2u);
}

TEST_F(P3ATimePeriodEventsMetricUnitTest, PeriodRollover) {
  CreateMetric();

  for (size_t i = 0; i < 6; i++) {
    metric_->HandleHistogramChange(kTestHistogramName, 1);
  }
  EXPECT_EQ(report_count_, 7);
  EXPECT_EQ(last_reported_value_, 1u);

  task_environment_.FastForwardBy(base::Days(6));
  EXPECT_EQ(report_count_, 13);
  EXPECT_EQ(last_reported_value_, 1u);

  task_environment_.FastForwardBy(base::Days(1));

  EXPECT_EQ(report_count_, 14);
  EXPECT_EQ(last_reported_value_, 0u);
}

}  // namespace p3a
