//
//  ViewController.m
//  BYBLivePlayer
//
//  Created by 白永炳 on 2017/6/23.
//  Copyright © 2017年 BYB. All rights reserved.
//

#import "ViewController.h"
#import <IJKMediaFramework/IJKMediaFramework.h>
#import <RongIMLib/RongIMLib.h>
#import "BarrageRenderer/BarrageHeader.h"
#import "UIImage+Barrage.h"
#import "NSSafeObject.h"
#import "AFNetworking.h"

#import <CommonCrypto/CommonDigest.h>

#define APPKEY @"c9kqb3rdk07wj"
#define APP_SECRET @"rgnDigQdX1HBQ"

NSString *const RCDLiveKitDispatchMessageNotification = @"RCDLiveKitDispatchMessageNotification";

@interface ViewController ()<RCIMClientReceiveMessageDelegate>

@property(nonatomic, strong)IJKFFMoviePlayerController *livePlayer;

@property(nonatomic, strong)BarrageRenderer *BarrageRender;

@property(nonatomic, strong)NSTimer *renderTimer;

@property(nonatomic, assign)NSInteger index;

@property(nonatomic, strong)NSString *tokenStr;

@property(nonatomic, strong)NSString *userId;
///
@property(nonatomic, strong) UIButton *sendMessBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self getRongToken];
    
//    UIView *liveRoom = [[UIView alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, self.view.bounds.size.height - 60)];
//    [self.view addSubview:liveRoom];
//    self.view.userInteractionEnabled = YES;
    
    [self initLivePlayer];
    
    [self addObserve];
    
    [self initBarrageRender];
    
    UIButton *sendMesBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
    self.sendMessBtn = sendMesBtn;
    sendMesBtn.frame = CGRectMake(100, 20, 100, 40);
    sendMesBtn.backgroundColor = [UIColor cyanColor];
    [sendMesBtn setTitle:@"发送消息" forState:(UIControlStateNormal)];
    sendMesBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [sendMesBtn addTarget:self action:@selector(sendMessageClick:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.livePlayer.view addSubview:sendMesBtn];
    
}

- (void)sendMessageClick:(UIButton *)sender
{
    RCTextMessage *testMessage = [RCTextMessage messageWithContent:@"I Love you Forever"];
    
   [[RCIMClient sharedRCIMClient] sendMessage:ConversationType_CHATROOM targetId:@"BYBLiveRoom1" content: testMessage pushContent:nil pushData:nil success:^(long messageId) {
       NSLog(@"发送消息成功");
   } error:^(RCErrorCode nErrorCode, long messageId) {
       NSLog(@"messageError == %ld", (long)nErrorCode);
   }];
}

- (void)initLivePlayer
{
    IJKFFOptions *options = [IJKFFOptions optionsByDefault];
    [options setPlayerOptionIntValue:1 forKey:@"videotoolbox"];
    // 帧速
    [options setPlayerOptionIntValue:29.97 forKey:@"r"];
    // 音量
    [options setPlayerOptionIntValue:512 forKey:@"vol"];
    //
    IJKFFMoviePlayerController *livePlayer = [[IJKFFMoviePlayerController alloc] initWithContentURLString:@"http://pull99.a8.com/live/1499006414142793.flv?ikHost=ws&ikOp=1&codecInfo=8192" withOptions:options];
    
    self.livePlayer = livePlayer;
    
    livePlayer.view.frame = self.view.bounds;
    
    livePlayer.scalingMode = IJKMPMovieScalingModeFill;
    
    livePlayer.shouldAutoplay = NO;
    
    [self.view insertSubview:livePlayer.view atIndex:0];
    
//    livePlayer.view.userInteractionEnabled = YES;
    
    [livePlayer prepareToPlay];
    

}


- (void)getRongToken
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    
    NSString *random = [NSString stringWithFormat:@"%d", arc4random()];
    NSDate *date = [NSDate date];
    
    NSString *timeStamp = [NSString stringWithFormat:@"%d",(int)[date timeIntervalSince1970]];
    
    NSString *signature = [self RongSha1:[NSString stringWithFormat:@"%@%@%@",APP_SECRET,random,timeStamp]];
    
    [manager.requestSerializer setValue:APPKEY forHTTPHeaderField:@"App-Key"];
    [manager.requestSerializer setValue:random forHTTPHeaderField:@"Nonce"];
    [manager.requestSerializer setValue:timeStamp forHTTPHeaderField:@"Timestamp"];
    [manager.requestSerializer setValue:signature forHTTPHeaderField:@"Signature"];

    NSDictionary  *parame = [NSMutableDictionary dictionaryWithCapacity:0];
    [parame setValue:@"13869607690" forKey:@"userId"];  // 15501161871
    [parame setValue:@"Synchronized" forKey:@"name"];  // BryanBai
//    [parame setValue:@"" forKey:<#(nonnull NSString *)#>]
    
//    [parame setValue:@"15501161871" forKey:@"userId"];  // 15501161871
//    [parame setValue:@"BryanBai" forKey:@"name"];  // BryanBai

    
    NSString *tokenUrl = @"https://api.cn.rong.io/user/getToken.json";
    
    [manager POST:tokenUrl parameters:parame success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject) {
        
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:(NSData *)responseObject options:0 error:nil];
        
        if ([dic objectForKey:@"token"] != nil) {
            self.tokenStr = [dic objectForKey:@"token"];
        }
        
        if (self.tokenStr) {
            [[RCIMClient sharedRCIMClient] connectWithToken:self.tokenStr success:^(NSString *userId) {
                self.userId = userId;
                NSLog(@"userId == %@", userId);
            } error:^(RCConnectErrorCode status) {
                NSLog(@"errorStatus == %d", status);
            } tokenIncorrect:^{
                NSLog(@"tokenError");
            }];
        }
        
        NSLog(@"dataDic == %@", dic);
        
    } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
        NSLog(@"error == %@", error);
    }];
}

- (NSString *)RongSha1:(NSString *)input
{
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH *2];
    
    for(int i=0; i<CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}


- (void)initBarrageRender
{
    self.BarrageRender = [[BarrageRenderer alloc] init];
    self.BarrageRender.smoothness = .2f;
    [self.livePlayer.view addSubview:self.BarrageRender.view];
    
    _BarrageRender.view.userInteractionEnabled = YES;
    _BarrageRender.canvasMargin = UIEdgeInsetsMake(10, 10, 10, 10);
    
    [self.livePlayer.view sendSubviewToBack:_BarrageRender.view];
    
}

- (void)addObserve
{
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadStateDidChange:) name:IJKMPMoviePlayerLoadStateDidChangeNotification object:self.livePlayer];
    [self registerNotification];
}

- (void)registerNotification {
    //注册接收消息
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(didReceiveMessageNotification:)
     name:RCDLiveKitDispatchMessageNotification
     object:nil];
}

- (void)didReceiveMessageNotification:(NSNotification *)notification {
   
    RCMessage *received = notification.object;
    NSLog(@"message == %@", received.content);
}


- (void)loadStateDidChange:(NSNotificationCenter *)notification
{
    if ((self.livePlayer.loadState & IJKMPMovieLoadStatePlaythroughOK) != 0) {
        if (!self.livePlayer.isPlaying) {
            [self.livePlayer play];
            [self starBarrageRender];
            [self  addChatRoomWithID:nil];
            
        }else
        {
            [self stopMockingBarrageMessage];
        }
    }else if (self.livePlayer.loadState &IJKMPMovieLoadStateStalled)
    {
        [self stopMockingBarrageMessage];
    }
}

- (void)starBarrageRender
{
    [_BarrageRender start];
    [self startMockingBarrageMessage];
}

- (void)startMockingBarrageMessage
{
    if ([self.renderTimer isValid]) {
        [self.renderTimer invalidate];
    }
    NSSafeObject * safeObj = [[NSSafeObject alloc]initWithObject:self withSelector:@selector(autoSendBarrage)];
    _renderTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:safeObj selector:@selector(excute) userInfo:nil repeats:YES];
}

- (void)stopMockingBarrageMessage
{
    [self.renderTimer invalidate];
}


- (void)autoSendBarrage
{
    NSInteger spritNumber = [_BarrageRender spritesNumberWithName:nil];
    if (spritNumber <= 500) {
        [self.BarrageRender receive:[self walkTextSpriteDescriptorWithDirection:BarrageWalkDirectionR2L side:(BarrageWalkSideLeft) withMessage:nil]];
        
    }
}

- (BarrageDescriptor *)walkTextSpriteDescriptorWithDirection:(BarrageWalkDirection)direction side:(BarrageWalkSide)side withMessage:(NSString *)message;
{
    BarrageDescriptor *descriptor = [[BarrageDescriptor alloc] init];
    descriptor.spriteName = NSStringFromClass([BarrageWalkTextSprite class]);
    descriptor.params[@"bizMsgId"] = [NSString stringWithFormat:@"%ld",(long)_index];
    if (message) {
        descriptor.params[@"text"] = message;

    }else
    {
        descriptor.params[@"text"] = [NSString stringWithFormat:@"过场文字弹幕奥西吧:%ld",(long)_index++];

    }
    descriptor.params[@"textColor"] = [UIColor blueColor];
    descriptor.params[@"speed"] = @(100 * (double)random()/RAND_MAX+50);
    descriptor.params[@"direction"] = @(direction);
    descriptor.params[@"side"] = @(side);
    descriptor.params[@"clickAction"] = ^(NSDictionary *params){
        NSString *msg = [NSString stringWithFormat:@"弹幕 %@ 被点击",params[@"bizMsgId"]];
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"提示" message:msg delegate:nil cancelButtonTitle:@"取消" otherButtonTitles:nil];
        [alertView show];
    };
    return descriptor;
}

- (void)addChatRoomWithID:(NSString *)chatRoomId
{
   [[RCIMClient sharedRCIMClient] joinChatRoom:@"BYBLiveRoom1" messageCount:-1 success:^{
       NSLog(@"加入聊天室成功");
       [[RCIMClient sharedRCIMClient] setReceiveMessageDelegate:self object:nil];
   } error:^(RCErrorCode status) {
       NSLog(@"joinChatRoomFailed == %ld", (long)status);
   }];
}

#pragma mark  RCIMClientReceiveMessageDelegate

- (void)onReceived:(RCMessage *)message left:(int)nLeft object:(id)object
{
    
    RCTextMessage  *mcontent = (id)message.content;
    NSLog(@"received Message == %@", mcontent.content);
    
    [self.BarrageRender receive:[self walkTextSpriteDescriptorWithDirection:BarrageWalkDirectionR2L side:BarrageWalkSideLeft withMessage:mcontent.content]];
}

- (void)dealloc
{
    if (self.livePlayer) {
        [self.livePlayer.view removeFromSuperview];
        self.livePlayer = nil;
    }
    [self stopMockingBarrageMessage];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end