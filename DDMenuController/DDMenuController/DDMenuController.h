//
//  DDMenuController.h
//  DDMenuController
//
//  Created by Devin Doty on 11/30/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    DDMenuPanDirectionLeft = 0,
    DDMenuPanDirectionRight,
} DDMenuPanDirection;

typedef enum {
    DDMenuPanCompletionLeft = 0,
    DDMenuPanCompletionRight,
    DDMenuPanCompletionRoot,
} DDMenuPanCompletion;

@protocol DDMenuControllerDelegate;
@interface DDMenuController : UINavigationController {
    
    id _tap;
    id _pan;
    
    CGFloat _panOriginX;
    CGPoint _panVelocity;
    DDMenuPanDirection _panDirection;

    struct {
        unsigned int respondsToWillShowController:1;
        unsigned int showingLeftView:1;
        unsigned int showingRightView:1;
        unsigned int canShowRight:1;
        unsigned int canShowLeft:1;
    } _menuFlags;
    
}

@property(nonatomic,assign) id <DDMenuControllerDelegate,UINavigationControllerDelegate> delegate;

@property(nonatomic,strong) UIViewController *leftController;
@property(nonatomic,strong) UIViewController *rightController;

@property(nonatomic,readonly) UITapGestureRecognizer *tap;
@property(nonatomic,readonly) UIPanGestureRecognizer *pan;

@end

@protocol DDMenuControllerDelegate 
- (void)menuController:(DDMenuController*)controller willShowController:(UIViewController*)controller;
@end