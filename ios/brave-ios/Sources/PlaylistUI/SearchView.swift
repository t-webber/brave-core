// Copyright (c) 2024 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import DesignSystem
import BraveUI
import Data
import Playlist
import SDWebImage
import Introspect

struct VideoResult: Codable {
  struct Thumbnail: Codable {
    var src: String
    var original: String
  }
  struct Author: Codable {
    var name: String
  }
  struct VideoData: Codable {
    var duration: String?
    var views: Int?
    var creator: String?
    var publisher: String?
    var requiresSubscription: Bool?
//    var tags: [String]
    var author: Author?
    
    var isEmpty: Bool {
      duration == nil && views == nil && creator == nil && publisher == nil && requiresSubscription == nil && author == nil
    }
    
    var convertedDuration: TimeInterval {
      guard let duration, !duration.isEmpty else {
        return 0
      }
      var value: TimeInterval = 0
      let parts = duration.components(separatedBy: ":").reversed()
      for (index, part) in parts.enumerated() {
        value += (TimeInterval(part) ?? 0) * pow(TimeInterval(60), TimeInterval(index))
      }
      return value
    }
  }
  var url: String
  var title: String
  var description: String
  var age: String?
  var thumbnail: Thumbnail?
  var video: VideoData
}

class SearchAPI {
  private let key = "BSAIXmItM9gfOtH_Ea5kcgKl_Zs5CF5"
  private let session = URLSession.shared
  
  private struct VideoSearchApiResponse: Codable {
    var results: [VideoResult]
  }
  
  func mockData() throws -> [VideoResult] {
    let data = Data(mockResponse.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(VideoSearchApiResponse.self, from: data).results
  }
  
  func search(query: String, count: Int = 20) async throws -> [VideoResult] {
    var components = URLComponents(string: "https://api.search.brave.com/res/v1/videos/search")!
    components.queryItems = [
      .init(name: "q", value: query),
      .init(name: "count", value: String(count))
//      .init(name: "country", value: Locale.current.region?.identifier ?? "us"),
//      .init(name: "search_lang", value: Locale.current.language.languageCode?.identifier ?? "en"),
//      .init(name: "ui_lang", value: Locale.current.identifier)
    ]
    var request = URLRequest(url: components.url!)
    request.setValue(key, forHTTPHeaderField: "X-Subscription-Token")
    
    let (data, response) = try await session.data(for: request)
    print(String(decoding: data, as: UTF8.self))
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(VideoSearchApiResponse.self, from: data).results.filter {
      !$0.video.isEmpty
    }
  }
}

struct VideoView: View {
  var video: VideoResult
  
  var body: some View {
    HStack {
      Color.clear
        .aspectRatio(16/9, contentMode: .fit)
        .frame(maxWidth: 124)
        .overlay {
          if let thumbnail = video.thumbnail {
            AsyncImage(url: URL(string: thumbnail.src)) { phase in
              phase.image?.resizable()
            }
            .aspectRatio(contentMode: .fill)
          }
        }
        .overlay(alignment: .bottomTrailing) {
          if let duration = video.video.duration {
            Text(duration)
              .foregroundStyle(.white)
              .font(.footnote)
              .padding(4)
              .background(Material.regular, in: .rect(cornerRadius: 4))
              .environment(\.colorScheme, .dark)
              .padding(4)
          }
        }
        .clipShape(.rect(cornerRadius: 10))
      VStack(alignment: .leading) {
        HStack(spacing: 2) {
          if let publisher = video.video.publisher {
            Text(publisher)
          }
          if let authorName = video.video.author?.name {
            Image(braveSystemName: "leo.carat.right")
            Text(authorName)
          }
        }
        .lineLimit(1)
        .imageScale(.small)
        .font(.footnote)
        .foregroundStyle(Color(braveSystemName: .textTertiary))
        Text(video.title)
          .font(.headline)
          .lineLimit(2)
          .foregroundStyle(Color(braveSystemName: .textPrimary))
        Text(video.description)
          .font(.subheadline)
          .lineLimit(1)
          .foregroundStyle(Color(braveSystemName: .textSecondary))
        HStack(spacing: 8) {
          if let age = video.age {
            Text(age)
          }
          HStack(spacing: 2) {
            if let views = video.video.views {
              Image(braveSystemName: "leo.eye.on")
              Text(views, format: .number)
            }
          }
        }
        .lineLimit(1)
        .foregroundStyle(Color(braveSystemName: .textTertiary))
        .font(.footnote)
      }
    }
  }
}

struct SearchView: View {
  @Environment(\.dismiss) private var dismiss
  
  @State private var query: String = ""
  @State private var videoResults: [VideoResult] = []
  @State private var isLoading: Bool = false
  
  @FocusState private var isSearchFocused: Bool
  
  @MainActor private func addVideo(_ videoResult: VideoResult) {
    let info: PlaylistInfo = .init(
      name: videoResult.title,
      src: "",
      pageSrc: videoResult.url,
      pageTitle: videoResult.title,
      mimeType: "video",
      duration: videoResult.video.convertedDuration,
      lastPlayedOffset: 0,
      detected: true,
      dateAdded: .now,
      tagId: "",
      order: 0,
      isInvisible: false
    )
    PlaylistItem.addItem(info, cachedData: nil)
    Task.detached {
      if let thumbnail = videoResult.thumbnail, let thumbnailURL = URL(string: thumbnail.src) {
        let cacheKey = "playlist-\(videoResult.url)"
        let image = try await UIImage(data: URLSession.shared.data(from: thumbnailURL).0)
        await SDImageCache.shared.store(image, forKey: cacheKey)
      }
    }
  }
  
  var body: some View {
    NavigationStack {
      List {
        ForEach(videoResults, id: \.url) { video in
          let isVideoInPlaylist = PlaylistItem.itemExists(pageSrc: video.url)
          Button {
            if !isVideoInPlaylist {
              addVideo(video)
            }
          } label: {
            VideoView(video: video)
          }
          .disabled(isVideoInPlaylist)
          .opacity(isVideoInPlaylist ? 0.2 : 1)
          .overlay {
            if isVideoInPlaylist {
              Label("Added to Playlist", braveSystemImage: "leo.product.playlist-added")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Material.ultraThin, in: .capsule)
                .font(.subheadline)
                .foregroundStyle(Color(braveSystemName: .textPrimary))
            }
          }
          .listRowBackground(Color(braveSystemName: .containerBackground))
        }
      }
      .scrollContentBackground(.hidden)
      .background {
        VStack {
          Image("waves-bg", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .opacity(0.2)
          Spacer()
          Image("waves-bg", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .opacity(0.2)
            .rotationEffect(.degrees(180))
        }
        .ignoresSafeArea()
      }
      .background(Color(braveSystemName: .containerBackground))
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search the web privately…")
      .osAvailabilityModifiers { content in
        if #available(iOS 18, *) {
          content.searchFocused($isSearchFocused)
        } else {
          content
        }
      }
      .onAppear {
        // TODO: Generate search queries based on the users last watched videos using Leo to automatically populate suggestions
        isSearchFocused = true
      }
      .onSubmit(of: .search) {
        isSearchFocused = false
        Task {
          isLoading = true
          do {
            let results = try await SearchAPI().search(query: query)
            withAnimation {
              videoResults = results
            }
          } catch {
            print(error)
          }
          isLoading = false
        }
      }
      .listStyle(.plain)
      .navigationTitle("Brave Search")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .cancellationAction) {
          Button(role: .cancel) {
            dismiss()
          } label: {
            Text("Cancel")
          }
          .foregroundStyle(.white)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          if isLoading {
            ProgressView()
              .progressViewStyle(.circular)
          }
        }
      }
    }
  }
}

private let mockResponse = #"""
{
  "type": "videos",
  "query": {
    "original": "Caboodle",
    "spellcheck_off": false,
    "show_strict_warning": false
  },
  "results": [
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=SKVv3qPRMoo",
      "title": "The MUST HAVE Items in My Caboodle | My Go To Travel Makeup Bag - YouTube",
      "description": "City Beauty Cyber Sale 40% Off No Code Needed 💋https://aspireiq.go2cloud.org/SH3ksSun Diego and Clear are my favorite Gloss Shades 🥰Caboodle~https://bit.ly...",
      "age": "November 22, 2023",
      "page_age": "2023-11-22T21:59:53",
      "video": {
        "duration": "22:44",
        "views": 17368,
        "creator": "LisaLisaD1",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "mature makeup"
        ],
        "author": {
          "name": "LisaLisaD1",
          "url": "http://www.youtube.com/@LisaLisaD1"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/oBtCgPupvyZ0P3TDNZu6eKJtQsttXezHZZ3pwdBQ_iM/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9T/S1Z2M3FQUk1vby9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/SKVv3qPRMoo/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=w6edC9hZmE8",
      "title": "Unboxing April's Deluxe Caboodle Club! 💌 - YouTube",
      "description": "Unboxing this month's Deluxe Caboodle Club feels like sewing heaven! From threads to needles, we've got it all stitched up. Join the Deluxe Caboodle and rece...",
      "age": "April 7, 2024",
      "page_age": "2024-04-07T12:00:59",
      "video": {
        "duration": "01:00",
        "views": 1836,
        "creator": "Spellbinders Paper Arts",
        "publisher": "YouTube",
        "requires_subscription": false,
        "author": {
          "name": "Spellbinders Paper Arts",
          "url": "http://www.youtube.com/@spellbinders"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/1sF6GSR5WlsRuLb2rrTygXJHY8BegJcBI7jB_FmHc60/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS93/NmVkQzloWm1FOC9v/YXIyLmpwZz9zcXA9/LW9heW13RWRDSlVE/RU5BRlNGV1FBZ0h5/cTRxcEF3d0lBUlVB/QUloQ2NBSEFBUVk9/JmFtcDtycz1BT240/Q0xBT0hfeHplS2E0/TS1idFN2MHcyeThC/VWJ5eThB",
        "original": "https://i.ytimg.com/vi/w6edC9hZmE8/oar2.jpg?sqp=-oaymwEdCJUDENAFSFWQAgHyq4qpAwwIARUAAIhCcAHAAQY=&amp;rs=AOn4CLAOH_xzeKa4M-btSv0w2y8BUbyy8A"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=TOISIET3j8w",
      "title": "AWESOME Vintage Caboodles Haul 💞 Thrifted Finds! - YouTube",
      "description": "I scored several vintage 80s Caboodles last week at estate sales, and I'm excited to show you my thrifted finds! They were all a great bargain but required s...",
      "age": "3 weeks ago",
      "page_age": "2024-09-03T20:21:03",
      "video": {
        "duration": "14:41",
        "views": 133,
        "creator": "Abby's Retro Rescue",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "pink caboodles"
        ],
        "author": {
          "name": "Abby's Retro Rescue",
          "url": "http://www.youtube.com/@AbbysRetroRescue"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/9TNLlRaCzRZTeqjP3YoX6lpYlPkhoZhyYPN2-gFMzJA/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9U/T0lTSUVUM2o4dy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/TOISIET3j8w/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=c8bTHRODJ4I",
      "title": "Inside Out 2 Movie DIY Custom Back to School Locker Organization COMPILATION! - YouTube",
      "description": "Lets organize with the Inside Out 2 movie DIY custom back to school lockers including Anger, Anxiety, Joy, Sadness, and Fear dolls during their school day. W...",
      "age": "August 21, 2024",
      "page_age": "2024-08-21T17:13:20",
      "video": {
        "duration": "15:33",
        "views": 17380,
        "creator": "Fun Caboodle",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "back to school organization"
        ],
        "author": {
          "name": "Fun Caboodle",
          "url": "http://www.youtube.com/@FunCaboodle"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/PS_xkaPIzUvUkUvRXdVVL2lvuXFURSeRhxNTfw3GGvU/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9j/OGJUSFJPREo0SS9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/c8bTHRODJ4I/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=HjGVFQn4Vi4",
      "title": "Unbox a splash of creativity with our August Deluxe Caboodle Club! - YouTube",
      "description": "Get ALL 10 club kits + our Exclusive Bonus: Bold Splatters BetterPress Plate Set! Dive into a world of 'colorful expressions'—this month's theme is all about...",
      "age": "August 9, 2024",
      "page_age": "2024-08-09T10:00:18",
      "video": {
        "duration": "00:56",
        "views": 678,
        "creator": "Spellbinders Paper Arts",
        "publisher": "YouTube",
        "requires_subscription": false,
        "author": {
          "name": "Spellbinders Paper Arts",
          "url": "http://www.youtube.com/@spellbinders"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/2qxfBaiIF2SnmNXmafvgdFlx0F_rym0OiEOSh4Cu1BI/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9I/akdWRlFuNFZpNC9v/YXIyLmpwZz9zcXA9/LW9heW13RWRDSlVE/RU5BRlNGV1FBZ0h5/cTRxcEF3d0lBUlVB/QUloQ2NBSEFBUVk9/JmFtcDtycz1BT240/Q0xDOXZ5YWlJNDlK/ZlZSd2l6dVdINGtK/TVhQVkFB",
        "original": "https://i.ytimg.com/vi/HjGVFQn4Vi4/oar2.jpg?sqp=-oaymwEdCJUDENAFSFWQAgHyq4qpAwwIARUAAIhCcAHAAQY=&amp;rs=AOn4CLC9vyaiI49JfVRwizuWH4kJMXPVAA"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=cbIk4hJGT4s",
      "title": "NEW! Dollar Tree Caboodle Box January 2024 - YouTube",
      "description": "In today’s video, I’m sharing the new Caboodle Box from the Dollar Tree! Happy Crafting and Continue to Spread Kindness!This video is for audiences 18 and ov...",
      "age": "January 11, 2024",
      "page_age": "2024-01-11T18:17:09",
      "video": {
        "duration": "01:53",
        "views": 2414,
        "creator": "Tricescraftylife",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "craft with me"
        ],
        "author": {
          "name": "Tricescraftylife",
          "url": "http://www.youtube.com/@tricescraftylife"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/abn89lC_xARoIjO_hQY0CGm6ODYbSNhD0phXdC18bsE/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9j/YklrNGhKR1Q0cy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/cbIk4hJGT4s/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=YNToEktHehs",
      "title": "Dollar Tree Valentine's Day Gift Idea Make Up Caboodle and Haul! 2024 - YouTube",
      "description": "My new Bow Tutorialhttps://youtu.be/rHpwqD5wvtQ2024 DOLLAR TREE Valetine's Gift Basketshttps://youtu.be/nCUdhlGiTH8DOLLAR TREE Valentine's Day PINK Tree DIYh",
      "age": "January 15, 2024",
      "page_age": "2024-01-15T01:15:26",
      "video": {
        "duration": "09:12",
        "views": 31043,
        "creator": "Bianca Andress",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "diy gift"
        ],
        "author": {
          "name": "Bianca Andress",
          "url": "http://www.youtube.com/@xoxoleopardworld"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/jcJOv96aePOQJ85LTbfCr21Kt-ciG1V0IrufkBr6Xa8/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9Z/TlRvRWt0SGVocy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/YNToEktHehs/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=TwoJ6V9QF5Y",
      "title": "Disney Elemental Movie Activity Coloring Book with Ember and Wade - YouTube",
      "description": "Disney Elemental Movie characters are revealing colors and activities in the coloring activity book. There are so many fun coloring book pages inside this bo...",
      "age": "November 22, 2023",
      "page_age": "2023-11-22T20:58:44",
      "video": {
        "duration": "04:49",
        "views": 506539,
        "creator": "Fun Caboodle",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "coloring"
        ],
        "author": {
          "name": "Fun Caboodle",
          "url": "http://www.youtube.com/@FunCaboodle"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/xdfPOE7X16EsFPVC0h9RnGBAG8ypOapP5ufiVzKNDSI/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9U/d29KNlY5UUY1WS9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/TwoJ6V9QF5Y/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=G4EQ6HZkl5s",
      "title": "Mixing Cute Squishies, Slime, Plushies Together into One Bowl - YouTube",
      "description": "Today I am cutting and mixing some of my squishies and slime together into one big bowl. These squishies are from my squishy collection creation. These squis...",
      "age": "November 21, 2023",
      "page_age": "2023-11-21T17:20:37",
      "video": {
        "duration": "08:01",
        "views": 6337534,
        "creator": "Fun Caboodle",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "slime asmr"
        ],
        "author": {
          "name": "Fun Caboodle",
          "url": "http://www.youtube.com/@FunCaboodle"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/wTEBShtmFVyGmEEGbKQMhzLXCtz5If9rOWgnq64d4m0/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9H/NEVRNkhaa2w1cy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/G4EQ6HZkl5s/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=Szs5Huor-0M",
      "title": "Trolls Band Together Movie DIY Color Changing Nail Polish Custom COMPILATION! Crafts for Kids - YouTube",
      "description": "This is a diy custom Disney Trolls Band Together movie color changing nail polish craft custom with Poppy, Branch, Viva, Bridget, Cloud Guy, and Crimp charac...",
      "age": "November 15, 2023",
      "page_age": "2023-11-15T22:13:29",
      "video": {
        "duration": "12:21",
        "views": 1952346,
        "creator": "Fun Caboodle",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "trolls band together cloud guy"
        ],
        "author": {
          "name": "Fun Caboodle",
          "url": "http://www.youtube.com/@FunCaboodle"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/IzMzMmNEURILCaH8fvTMhKAD5l3h_UrXPJv7873QVSo/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9T/enM1SHVvci0wTS9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/Szs5Huor-0M/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=DDWIePtOTfg",
      "title": "Introducing: Country Caboodle Pillow Wrap Club | Shabby Fabrics - YouTube",
      "description": "Designed by Leanne Anderson & Kaytlyn Kuebler, join us for a whole bunch of fun in the Country Caboodle Pillow Wrap Club! You’ll begin to create a seasonal d...",
      "age": "November 7, 2023",
      "page_age": "2023-11-07T23:23:23",
      "video": {
        "duration": "04:40",
        "views": 18381,
        "creator": "Shabby Fabrics",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "laser cut applique pillow"
        ],
        "author": {
          "name": "Shabby Fabrics",
          "url": "http://www.youtube.com/@ShabbyFabrics"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/atO0KouVamoRQf4Bm-zlyvmMU7LMDbsEWvsN9Ndk8F0/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9E/RFdJZVB0T1RmZy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/DDWIePtOTfg/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=alARCyazAiU",
      "title": "The Super Mario Bros Movie DIY Custom Back to School Locker Organization COMPILATION! - YouTube",
      "description": "Lets organize with The Super Mario Bros movie DIY custom back to school lockers including Mario, Luigi, Peach, Toad, and Bowser dolls during their school day...",
      "age": "April 19, 2023",
      "page_age": "2023-04-19T20:17:43",
      "video": {
        "duration": "17:11",
        "views": 26648708,
        "creator": "Fun Caboodle",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "locker organization"
        ],
        "author": {
          "name": "Fun Caboodle",
          "url": "http://www.youtube.com/@FunCaboodle"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/LXiAw5BpCSZ6x9BWF8pZr_js-6l7e3QijsOoO-gKIGk/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9h/bEFSQ3lhekFpVS9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/alARCyazAiU/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=WuLfIC6W2-o",
      "title": "ASMR Caboodle Rummage! (No talking) Makeup organization & rummaging/plastic case clicking & lids. - YouTube",
      "description": "This video was a suggestion from a very kind subscriber who suggested that I do a caboodles video. I was excited to find that a caboodle case could be found ...",
      "age": "March 23, 2022",
      "page_age": "2022-03-23T15:01:14",
      "video": {
        "duration": "41:25",
        "views": 105878,
        "creator": "Rebecca’s Beautiful ASMR Addiction",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "ASMR No talking"
        ],
        "author": {
          "name": "Rebecca’s Beautiful ASMR Addiction",
          "url": "http://www.youtube.com/@RebeccasBeautifulASMRAddiction"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/L-9MhHbsehm-kzvF2Ox_AcV7_NOps4qCLUhL_pINVeY/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9X/dUxmSUM2VzItby9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/WuLfIC6W2-o/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=iKCqg1SNadg",
      "title": "Pack My Caboodle With Me ✨ - YouTube",
      "description": "level up your organization game✨💁‍♀️#caboodle #claires #clairesstores #makeup #beauty #caboodlecase #ASMR #fashion #styling #fyp",
      "age": "May 31, 2023",
      "page_age": "2023-05-31T14:07:07",
      "video": {
        "duration": "01:00",
        "views": 907,
        "creator": "Claire's Stores",
        "publisher": "YouTube",
        "requires_subscription": false,
        "author": {
          "name": "Claire's Stores",
          "url": "http://www.youtube.com/@ClairesStores"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/vNwgHBQus417jSXSf4sUd7yD8rFFu6CFXWjCWokgG7Q/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9p/S0NxZzFTTmFkZy9o/cTcyMC5qcGc_c3Fw/PS1vYXltd0VkQ0pV/REVOQUZTRlh5cTRx/cEF3OElBUlVBQUlo/Q2NBSEFBUWJRQVFF/PSZhbXA7cnM9QU9u/NENMQTdYZ0hGdmll/ZThrSlN4d0dQa0Rp/S0ZTVDFZZw",
        "original": "https://i.ytimg.com/vi/iKCqg1SNadg/hq720.jpg?sqp=-oaymwEdCJUDENAFSFXyq4qpAw8IARUAAIhCcAHAAQbQAQE=&amp;rs=AOn4CLA7XgHFviee8kJSxwGPkDiKFST1Yg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=866SIkAtMDA",
      "title": "Ulta Beauty Box Caboodles Edition Review & Try On 2021 | Christmas Gift Ideas - YouTube",
      "description": "In today’s video I’m reviewing and trying on the new Ulta Beauty Box Caboodles Pink edition. This beauty box costs $29.99 and you receive a caboodles case fi...",
      "age": "December 17, 2021",
      "page_age": "2021-12-17T00:13:53",
      "video": {
        "duration": "20:46",
        "views": 1570,
        "creator": "Norisbel Cayo",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "Holiday season"
        ],
        "author": {
          "name": "Norisbel Cayo",
          "url": "http://www.youtube.com/@norisbelcayo"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/AvIHr5VuwmUMYVMxiZCZ0rrSs8kSSNsTTw6FEMzICJc/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS84/NjZTSWtBdE1EQS9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/866SIkAtMDA/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=yMmXztRdcc8",
      "title": "Caboodles® On-The-Go Girl™ - YouTube",
      "description": "The one that started it all! The original, iconic Caboodle still features a spacious interior, removable accessory tray and flip lid mirror. Whether you met ...",
      "age": "September 4, 2019",
      "page_age": "2019-09-04T18:51:57",
      "video": {
        "duration": "00:20",
        "views": 10875,
        "creator": "Caboodles",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "professional organizer"
        ],
        "author": {
          "name": "Caboodles",
          "url": "http://www.youtube.com/@caboodles439"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/PjcsgAM4ewruKBOVdnpqVIeoP9QkwEGr_dZdFp5ZXlE/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS95/TW1YenRSZGNjOC9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/yMmXztRdcc8/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=XS33hc2d0ew",
      "title": "LET'S GET ORGANIZED! PnP Makeup Collection in my CABOODLE! - YouTube",
      "description": "Hi Everyone! 🤗Im back with a 💖Petite 'n Pretty Makeup collection & Organization video. Hopefully you will find this Aesthetically pleasing and that it will...",
      "age": "April 21, 2019",
      "page_age": "2019-04-21T14:23:40",
      "video": {
        "duration": "10:38",
        "views": 419095,
        "creator": "Jessalyn Grace",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "safe for kids"
        ],
        "author": {
          "name": "Jessalyn Grace",
          "url": "http://www.youtube.com/@JessalynGrace"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/3dsq_augTDqYLG4e9ptA3XPhcgWgww6KX7JymN4jd2M/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9Y/UzMzaGMyZDBldy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/XS33hc2d0ew/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=q_vHWb2IrH4",
      "title": "Caboodles® Large Train Case - YouTube",
      "description": "Now boarding for expert organization! Wave goodbye to clutter with this Caboodles® ultimate train case. Six cantilever trays hold small accessories and makeu...",
      "age": "September 4, 2019",
      "page_age": "2019-09-04T18:41:45",
      "video": {
        "duration": "00:19",
        "views": 5629,
        "creator": "Caboodles",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "professional organizer"
        ],
        "author": {
          "name": "Caboodles",
          "url": "http://www.youtube.com/@caboodles439"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/APJgRoHLPUoYOW9JelEZwCoDf_1oSCKn-kvUdC_SU9o/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS9x/X3ZIV2IySXJINC9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/q_vHWb2IrH4/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=uY2DPG7trdg",
      "title": "Caboodles® Pretty In Petite™ - YouTube",
      "description": "Everything is cuter in miniature form – including Caboodles! Think of the Pretty In Petite™ as the little sister to our iconic On-The-Go Girl™. With two swiv...",
      "age": "September 4, 2019",
      "page_age": "2019-09-04T18:53:30",
      "video": {
        "duration": "00:19",
        "views": 5086,
        "creator": "Caboodles",
        "publisher": "YouTube",
        "requires_subscription": false,
        "tags": [
          "professional organizer"
        ],
        "author": {
          "name": "Caboodles",
          "url": "http://www.youtube.com/@caboodles439"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/qgfRUaQ3EhX5YfnnTDhdkPbAvVYHNY7y_FXVeOwp6qw/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS91/WTJEUEc3dHJkZy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/uY2DPG7trdg/maxresdefault.jpg"
      }
    },
    {
      "type": "video_result",
      "url": "https://www.youtube.com/watch?v=0Cx0hgakRxs",
      "title": "Meet My Caboodle & I SHOP MY STASH: October 2017 - YouTube",
      "description": "I bought an OLD SCHOOL Caboodle and I'm filling it with \"shop my stash\" rediscovered products on a monthly basis! VERY random selection of stuff! My OG Caboo...",
      "age": "October 28, 2017",
      "page_age": "2017-10-28T15:01:14",
      "video": {
        "duration": "18:38",
        "views": 126122,
        "creator": "Emily Noel",
        "publisher": "YouTube",
        "tags": [
          "luxury"
        ],
        "author": {
          "name": "Emily Noel",
          "url": "http://www.youtube.com/@emilynoel83"
        }
      },
      "meta_url": {
        "scheme": "https",
        "netloc": "youtube.com",
        "hostname": "www.youtube.com",
        "favicon": "https://imgs.search.brave.com/Wg4wjE5SHAargkzePU3eSLmWgVz84BEZk1SjSglJK_U/rs:fit:32:32:1:0/g:ce/aHR0cDovL2Zhdmlj/b25zLnNlYXJjaC5i/cmF2ZS5jb20vaWNv/bnMvOTkyZTZiMWU3/YzU3Nzc5YjExYzUy/N2VhZTIxOWNlYjM5/ZGVjN2MyZDY4Nzdh/ZDYzMTYxNmI5N2Rk/Y2Q3N2FkNy93d3cu/eW91dHViZS5jb20v",
        "path": "› watch"
      },
      "thumbnail": {
        "src": "https://imgs.search.brave.com/P0oSnu7px8UoGIBbCEOVuJBBh4GGeMDLxiNWPF5aOUE/rs:fit:200:200:1:0/g:ce/aHR0cHM6Ly9pLnl0/aW1nLmNvbS92aS8w/Q3gwaGdha1J4cy9t/YXhyZXNkZWZhdWx0/LmpwZw",
        "original": "https://i.ytimg.com/vi/0Cx0hgakRxs/maxresdefault.jpg"
      }
    }
  ]
}
"""#

#if DEBUG
#Preview {
  SearchView()
}
#endif
