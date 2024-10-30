/* Copyright (c) 2024 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "base/strings/sys_string_conversions.h"
#include "net/http/http_response_headers.h"
#include "services/network/public/mojom/url_response_head.mojom.h"

#define startURLSchemeTask originalStartURLSchemeTask

#include "src/ios/web/webui/crw_web_ui_scheme_handler.mm"

#undef startURLSchemeTask

@interface CRWWebUISchemeHandler (Override)
- (void)webView:(WKWebView*)webView
    startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask;
@end

@implementation CRWWebUISchemeHandler (Override)
- (void)webView:(WKWebView*)webView
    startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
  GURL URL = net::GURLWithNSURL(urlSchemeTask.request.URL);
  // Check the mainDocumentURL as the URL might be one of the subresource, so
  // not a WebUI URL itself.
  NSInteger errorCode = GetErrorCodeForUrl(
      net::GURLWithNSURL(urlSchemeTask.request.mainDocumentURL));
  if (errorCode != 0) {
    NSError* error = [NSError
        errorWithDomain:NSURLErrorDomain
                   code:errorCode
               userInfo:@{
                 NSURLErrorFailingURLErrorKey : urlSchemeTask.request.URL,
                 NSURLErrorFailingURLStringErrorKey :
                     urlSchemeTask.request.URL.absoluteString
               }];
    [urlSchemeTask didFailWithError:error];
    return;
  }

  __weak CRWWebUISchemeHandler* weakSelf = self;
  std::unique_ptr<web::URLFetcherBlockAdapter> adapter =
      std::make_unique<web::URLFetcherBlockAdapter>(
          URL, _URLLoaderFactory,
          ^(NSData* data, web::URLFetcherBlockAdapter* fetcher) {
            CRWWebUISchemeHandler* strongSelf = weakSelf;
            if (!strongSelf ||
                strongSelf.map->find(urlSchemeTask) == strongSelf.map->end()) {
              return;
            }

            NSString* mimeType = @"text/html";
            base::FilePath filePath =
                base::FilePath(fetcher->getUrl().ExtractFileName());
            if (filePath.Extension() == ".js") {
              mimeType = @"text/javascript; charset=UTF-8";
            } else if (filePath.Extension() == ".css") {
              mimeType = @"text/css; charset=UTF-8";
            } else if (filePath.Extension() == ".svg") {
              mimeType = @"image/svg+xml";
            }

            const network::mojom::URLResponseHead* responseHead =
                fetcher->getResponse();
            if (responseHead) {
              const scoped_refptr<net::HttpResponseHeaders> headers =
                  responseHead->headers;
              if (headers) {
                // const std::string& raw_headers = headers->raw_headers();

                NSMutableDictionary* responseHeaders =
                    [strongSelf parseHeaders:headers];

                if (![responseHeaders objectForKey:@"Content-Type"]) {
                  [responseHeaders setObject:mimeType forKey:@"Content-Type"];
                }

                NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]
                     initWithURL:urlSchemeTask.request.URL
                      statusCode:200
                     HTTPVersion:@"HTTP/1.1"
                    headerFields:responseHeaders];

                [urlSchemeTask didReceiveResponse:response];
                [urlSchemeTask didReceiveData:data];
                [urlSchemeTask didFinish];
                [weakSelf removeFetcher:fetcher];
                return;
              }
            }

            NSDictionary* headers = @{
              @"Content-Type" : mimeType,
              @"Access-Control-Allow-Origin" : @"*"
            };

            NSHTTPURLResponse* response =
                [[NSHTTPURLResponse alloc] initWithURL:urlSchemeTask.request.URL
                                            statusCode:200
                                           HTTPVersion:@"HTTP/1.1"
                                          headerFields:headers];

            [urlSchemeTask didReceiveResponse:response];
            [urlSchemeTask didReceiveData:data];
            [urlSchemeTask didFinish];
            [weakSelf removeFetcher:fetcher];
          });
  _map.insert(std::make_pair(urlSchemeTask, std::move(adapter)));
  _map.find(urlSchemeTask)->second->Start();
}

- (NSMutableDictionary*)parseHeaders:
    (const scoped_refptr<net::HttpResponseHeaders>&)headers {
  NSMutableDictionary* result = [[NSMutableDictionary alloc] init];

  std::size_t iterator = 0;
  std::string name, value;
  while (headers->EnumerateHeaderLines(&iterator, &name, &value)) {
    [result setObject:base::SysUTF8ToNSString(value)
               forKey:base::SysUTF8ToNSString(name)];
  }

  return result;
}
@end
