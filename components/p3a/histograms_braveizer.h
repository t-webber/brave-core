/* Copyright (c) 2019 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#ifndef BRAVE_COMPONENTS_P3A_HISTOGRAMS_BRAVEIZER_H_
#define BRAVE_COMPONENTS_P3A_HISTOGRAMS_BRAVEIZER_H_

#include <memory>
#include <vector>

#include "base/memory/ref_counted.h"
#include "base/metrics/histogram_base.h"
#include "base/metrics/statistics_recorder.h"

namespace p3a {

class HistogramsBraveizer
    : public base::RefCountedThreadSafe<HistogramsBraveizer> {
 public:
  static scoped_refptr<p3a::HistogramsBraveizer> Create();

  HistogramsBraveizer();

  HistogramsBraveizer(const HistogramsBraveizer&) = delete;
  HistogramsBraveizer& operator=(const HistogramsBraveizer&) = delete;

 private:
  friend class base::RefCountedThreadSafe<HistogramsBraveizer>;
  ~HistogramsBraveizer();

  // Set callbacks for existing Chromium histograms that will be bravetized,
  // i.e. reemitted using a different name and custom buckets.
  void InitCallbacks();

  void DoHistogramBravetization(std::string_view histogram_name,
                                uint64_t name_hash,
                                base::HistogramBase::Sample32 sample);

  std::vector<
      std::unique_ptr<base::StatisticsRecorder::ScopedHistogramSampleObserver>>
      histogram_sample_callbacks_;
};

}  // namespace p3a

#endif  // BRAVE_COMPONENTS_P3A_HISTOGRAMS_BRAVEIZER_H_
