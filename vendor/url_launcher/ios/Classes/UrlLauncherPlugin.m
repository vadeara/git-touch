// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <SafariServices/SafariServices.h>

#import "UrlLauncherPlugin.h"

@interface FLTUrlLaunchSession : NSObject <SFSafariViewControllerDelegate>
@property(strong) SFSafariViewController *safari;
@end

@implementation FLTUrlLaunchSession {
  NSURL *_url;
  FlutterResult _flutterResult;
  void (^_completion)();
}

- (instancetype)initWithUrl:url withFlutterResult:result completion:completion {
  self = [super init];
  if (self) {
    _url = url;
    _flutterResult = result;
    _safari = [[SFSafariViewController alloc] initWithURL:url];
    _safari.delegate = self;
    _completion = completion;
  }
  return self;
}

- (void)safariViewController:(SFSafariViewController *)controller
      didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
  if (didLoadSuccessfully) {
    _flutterResult(nil);
  } else {
    _flutterResult([FlutterError
        errorWithCode:@"Error"
              message:[NSString stringWithFormat:@"Error while launching %@", _url]
              details:nil]);
  }
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
  [controller dismissViewControllerAnimated:YES completion:_completion];
}

- (void)close {
  [self safariViewControllerDidFinish:_safari];
}

@end

@implementation FLTUrlLauncherPlugin {
  UIViewController *_viewController;
  FLTUrlLaunchSession *_currentSession;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/url_launcher"
                                  binaryMessenger:registrar.messenger];
  UIViewController *viewController =
      [UIApplication sharedApplication].delegate.window.rootViewController;
  FLTUrlLauncherPlugin *plugin =
      [[FLTUrlLauncherPlugin alloc] initWithViewController:viewController];
  [registrar addMethodCallDelegate:plugin channel:channel];
}

- (instancetype)initWithViewController:(UIViewController *)viewController {
  self = [super init];
  if (self) {
    _viewController = viewController;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *url = call.arguments[@"url"];
  if ([@"canLaunch" isEqualToString:call.method]) {
    result(@([self canLaunchURL:url]));
  } else if ([@"launch" isEqualToString:call.method]) {
    NSNumber *useSafariVC = call.arguments[@"useSafariVC"];
    if (useSafariVC.boolValue) {
      [self launchURLInVC:url result:result];
    } else {
      [self launchURL:url result:result];
    }
  } else if ([@"closeWebView" isEqualToString:call.method]) {
    [self closeWebView:url result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (BOOL)canLaunchURL:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  UIApplication *application = [UIApplication sharedApplication];
  return [application canOpenURL:url];
}

- (void)launchURL:(NSString *)urlString result:(FlutterResult)result {
  NSURL *url = [NSURL URLWithString:urlString];
  UIApplication *application = [UIApplication sharedApplication];
  if ([application respondsToSelector:@selector(openURL:options:completionHandler:)]) {
    [application openURL:url
                  options:@{}
        completionHandler:^(BOOL success) {
          if (success) {
            result(nil);
          } else {
            result([FlutterError
                errorWithCode:@"Error"
                      message:[NSString stringWithFormat:@"Error while launching %@", url]
                      details:nil]);
          }
        }];
  } else {
    BOOL success = [application openURL:url];
    if (success) {
      result(nil);
    } else {
      result([FlutterError
          errorWithCode:@"Error"
                message:[NSString stringWithFormat:@"Error while launching %@", url]
                details:nil]);
    }
  }
}

- (void)launchURLInVC:(NSString *)urlString result:(FlutterResult)result {
  NSURL *url = [NSURL URLWithString:urlString];
  _currentSession = [[FLTUrlLaunchSession alloc] initWithUrl:url
                                           withFlutterResult:result
                                                  completion:^void() {
                                                    self->_currentSession = nil;
                                                  }];
  [_viewController presentViewController:_currentSession.safari animated:YES completion:nil];
}

- (void)closeWebView:(NSString *)urlString result:(FlutterResult)result {
  if (_currentSession != nil) {
    [_currentSession close];
  }
  result(nil);
}

@end
