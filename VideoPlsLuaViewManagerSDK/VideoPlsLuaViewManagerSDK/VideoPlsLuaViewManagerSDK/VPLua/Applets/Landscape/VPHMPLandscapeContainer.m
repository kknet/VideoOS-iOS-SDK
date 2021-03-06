//
//  VPHMPLandscapeContainer.m
//  VideoPlsLuaViewManagerSDK
//
//  Created by Zard1096-videojj on 2019/8/28.
//  Copyright © 2019 videopls. All rights reserved.
//

#import "VPHMPLandscapeContainer.h"
#import "VPLNodeController.h"
#import "VPUPRoutes.h"
#import "VPUPHexColors.h"
#import "VPUPEncryption.h"
#import "VPLDownloader.h"
#import "VPUPHexColors.h"
#import "VPUPViewScaleUtil.h"
#import "VPUPPathUtil.h"
#import "VPLMPWebView.h"
#import "VPUPJsonUtil.h"
#import "VPUPCommonInfo.h"
#import "VPUPActionManager.h"
#import "VPLSDK.h"
#import "VPUPValidator.h"
#import "VPLOSView.h"
#import "VPLNativeBridge.h"

@interface VPHMPLandscapeContainer()<VPUPBasicWebViewDelegate, VPLMPWebViewDelegate>

@property (nonatomic) VPLMPWebView *webView;

@property (nonatomic) NSMutableArray *nodeStack;

//applet
@property (nonatomic, assign) BOOL isMPRetry;
@property (nonatomic) NSString *tempRetryNodeId;
@property (nonatomic) id tempRetryData;
@property (nonatomic, assign) BOOL isMPError;

@end

@implementation VPHMPLandscapeContainer

- (void)initContainView {
    
    self.webView = [[VPLMPWebView alloc] initWithFrame:self.containFrame];
    self.webView.delegate = self;
    self.webView.jsMPDelegate = self;
    self.webView.landscape = YES;
//    [self.webView setUpWebViewWithFrame:self.containFrame];
//    [self.webView setDisableNativePayment:YES];
//    self.webView.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.mainView addSubview:self.webView];
}

- (void)setCurrentOrientation:(VPMPContainerOrientation)orientation {
    [super setCurrentOrientation:orientation];
    if (self.webView) {
        self.webView.landscape = (orientation == VPMPContainerOrientationPortriat ? NO : YES);
    }
}

- (void)updateContainView {
    [self.webView setFrame:self.containFrame];
}

- (void)updateContainUserInfo {
    if (self.getUserInfoBlock) {
        
    }
}

- (void)loadContainView {    
    [self updateNavi];
    self.webView.developUserId = self.mpObject.miniAppInfo.developerUserId;
    self.webView.mpID = self.mpObject.miniAppInfo.mpID;
    [self.webView loadUrl:self.mpObject.h5Url];
    [self closeLoadingView];
}

- (void)loadLFile:(NSString *)luaUrl data:(NSDictionary *)data {
    
}

- (void)refreshContainerWithData:(id)data {
    [self closeLoadingView];
    [self closeRetryView];
    [self closeErrorView];
    self.rootData = data;
    [self.webView loadUrl:@""];
    [self.webView loadUrl:self.mpObject.h5Url];
}

- (void)naviBackButtonTapped {
    if ([self.webView canGoBack]) {
        [self.webView goBack];

        if (self.errorView.hidden == NO) {
            [self closeErrorView];
            //小程序唤起的错误页,需要移除node;lua加载引发的错误页,不需要移除node
            if (_isMPError) {
                _isMPError = NO;
//                [_nodeController removeLastNode];
            }
        } else {
            if (self.retryView.hidden == NO) {
                //当前页面没有重试就回退了,置空所有参数
                if (_isMPError) {
                    _isMPError = NO;
                    _tempRetryNodeId = nil;
                    _tempRetryData = nil;
                }
                [self closeRetryView];
            }
//            [_nodeController removeLastNode];
        }
    } else {
        [self.naviBar hideBackButton];
    }
}

- (void)destroyView {
//    [self.nodeController releaseLuaView];
    [self.webView stop];
    [super destroyView];
}

#pragma mark - handle webView method

- (NSString *)getJSCallback:(NSDictionary *)params {
    if (!VPUP_IsStrictExist([params objectForKey:@"callback"])) {
        return nil;
    }
    
    return [params objectForKey:@"callback"];
}

- (void)jsCallback:(NSString *)callbackMethod params:(NSArray *)params {
    [_webView jsCallMethod:callbackMethod params:params];
}

- (void)getInitDataWithParameters:(NSDictionary *)params {
    NSString *jsCallback = [self getJSCallback:params];
    if (!jsCallback) {
        return;
    }
    
    NSMutableDictionary *sendParams = [NSMutableDictionary dictionary];
    
    NSDictionary *data = [self getInitData];
    NSArray *paramArray = nil;
    if (data) {
        [sendParams setObject:data forKey:@"data"];
        
        NSString *sendParamString = VPUP_DictionaryToJson(sendParams);
        
        if (sendParamString) {
            paramArray = [NSArray arrayWithObject:sendParamString];
        }
    }
    
    [self jsCallback:jsCallback params:paramArray];
}

- (void)showErrorPageWithParameters:(NSDictionary *)params {
    NSDictionary *dict = [params objectForKey:@"msg"];
    if (!dict) {
        return;
    }
    
    _isMPError = YES;
    [self showErrorView];
    if (!VPUP_IsStrictExist([dict objectForKey:@"message"])) {
        [self.errorView useDefaultMessage];
    } else {
        [self.errorView changeErrorMessage:[dict objectForKey:@"message"]];
    }
}

- (void)updateNaviTitleWithParameters:(NSDictionary *)params {
    NSDictionary *dict = [params objectForKey:@"msg"];
    if (!dict) {
        return;
    }
    if (VPUP_IsStrictExist([dict objectForKey:@"title"])) {
        [self.naviBar updateNaviTitle:[dict objectForKey:@"title"]];
    }
}

- (void)networkEncryptWithParameters:(NSDictionary *)params {
    NSString *jsCallback = [self getJSCallback:params];
    if (!jsCallback) {
        return;
    }
    NSDictionary *dict = [params objectForKey:@"msg"];
    if (!dict) {
        [self jsCallback:jsCallback params:nil];
        return;
    }
    if (!VPUP_IsStrictExist([dict objectForKey:@"data"]) || ![[dict objectForKey:@"data"] isKindOfClass:[NSString class]]) {
        [self jsCallback:jsCallback params:nil];
        return;
    }
    
    NSString *data = [dict objectForKey:@"data"];
    
    NSString *secretString = [VPLSDK sharedSDK].appSecret;
    
    NSString *result = [VPUPAESUtil aesEncryptString:data key:secretString initVector:secretString];
    
    NSMutableDictionary *sendParams = [NSMutableDictionary dictionary];
    [sendParams setObject:result forKey:@"encryptData"];
    
    NSString *sendParamString = VPUP_DictionaryToJson(sendParams);
    
    NSArray *paramArray = nil;
    if (sendParamString) {
        paramArray = [NSArray arrayWithObject:sendParamString];
    }
    
    [self jsCallback:jsCallback params:paramArray];
}

- (void)networkDecryptWithParameters:(NSDictionary *)params {
    NSString *jsCallback = [self getJSCallback:params];
    if (!jsCallback) {
        return;
    }
    NSDictionary *dict = [params objectForKey:@"msg"];
    if (!dict) {
        [self jsCallback:jsCallback params:nil];
        return;
    }
    if (!VPUP_IsStrictExist([dict objectForKey:@"data"]) || ![[dict objectForKey:@"data"] isKindOfClass:[NSString class]]) {
        [self jsCallback:jsCallback params:nil];
        return;
    }
    
    NSString *data = [dict objectForKey:@"data"];
    
    NSString *secretString = [VPLSDK sharedSDK].appSecret;
    
    NSString *result = [VPUPAESUtil aesDecryptString:data key:secretString initVector:secretString];
    
    NSString *base64Result = [VPUPBase64Util base64EncryptionString:result];
    
    NSMutableDictionary *sendParams = [NSMutableDictionary dictionary];
    [sendParams setObject:base64Result forKey:@"decryptData"];
    
    NSString *sendParamString = VPUP_DictionaryToJson(sendParams);
    
    NSArray *paramArray = nil;
    if (sendParamString) {
        paramArray = [NSArray arrayWithObject:sendParamString];
    }
    
    [self jsCallback:jsCallback params:paramArray];
}



- (void)closeViewWithParameters:(NSDictionary *)params {
    SEL selector = NSSelectorFromString(@"naviCloseButtonTapped");
    if ([self respondsToSelector:selector]) {
        [self performSelector:selector withObject:nil];
    }
}


#pragma mark - delegate
//js
- (void)callFromJSMethod:(NSString *)method args:(NSDictionary *)args {
    NSString *methodString = [NSString stringWithFormat:@"%@%@", method, @"WithParameters:"];
    
    SEL selector = NSSelectorFromString(methodString);
    if ([self respondsToSelector:selector]) {
        [self performSelector:selector withObject:args];
    }
}

//loadComplete
- (void)loadCompleteWithTitle:(NSString *)title error:(NSError *)error {
    if ([self.webView canGoBack]) {
        [self.naviBar showBackButton];
    } else {
        [self.naviBar hideBackButton];
    }
    [self.naviBar updateNaviTitle:title];
    if (!error) {
        [self closeLoadingView];
    } else {
        NSLog(@"======webview failed error: %@", error);
    }
}

- (void)webViewDidStartLoad {
    if ([self.webView canGoBack]) {
        [self.naviBar showBackButton];
    }
}

- (void)getUserInfo {
    
}


//network
- (void)retryNetwork {
    [self showLoadingView];
    if (!_isMPRetry) {
        [self showLoadingView];
        if (self.retryLFiles) {
            self.retryLFiles = false;
//            [self loadLFileFiles];
        } else {
            [super retryNetwork];
        }
    } else {
        _isMPRetry = NO;
        [self closeRetryView];
        if (_tempRetryNodeId) {
//            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
//                                  @(VPLMPActionTypeRetry),@"appletActionType",
//                                  @(VPLEventTypeMPAction), @"eventType",
//                                  _tempRetryData, @"data", nil];
//            [self.nodeController callLMethod:@"retry" nodeId:_tempRetryNodeId data:dict];
        }
        _tempRetryNodeId = nil;
        _tempRetryData = nil;
    }
    
}

//lua node controller
- (void)showRetryPage:(NSString *)retryMessage retryData:(id)data nodeId:(NSString *)nodeId {
    [self showRetryView];
    if (retryMessage != nil && ![retryMessage isEqualToString:@""]) {
        [self.retryView changeNetworkMessage:retryMessage];
    } else {
        [self.retryView useDefaultMessage];
    }
    _isMPRetry = YES;
    _tempRetryData = data;
    _tempRetryNodeId = nodeId;
}

- (void)showErrorPage:(NSString *)errorMessage {
    _isMPError = YES;
    [self showErrorView];
    if (errorMessage != nil && ![errorMessage isEqualToString:@""]) {
        [self.errorView changeErrorMessage:errorMessage];
    } else {
        [self.errorView useDefaultMessage];
    }
}

@end
