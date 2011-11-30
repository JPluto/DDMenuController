//
//  DDMenuController.m
//  DDMenuController
//
//  Created by Devin Doty on 11/30/11.
//  Copyright (c) 2011 toaast. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "DDMenuController.h"

#define kMenuOverlayWidth 40.0f
#define kMenuBounceOffset 4.0f
#define kMenuBounceDuration .3f
#define kMenuSlideDuration .3f


@interface DDMenuController (Internal)
- (void)showRootController:(BOOL)animated;
- (void)showRightController:(BOOL)animated; 
- (void)showLeftController:(BOOL)animated; 
- (void)showShadow:(BOOL)val;
@end

@implementation DDMenuController

@synthesize delegate;

@synthesize leftController=_left;
@synthesize rightController=_right;

@synthesize tap=_tap;
@synthesize pan=_pan;

- (id)initWithRootViewController:(UIViewController*)controller {
    if ((self = [super initWithRootViewController:controller])) {

    }
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!_tap) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [self.view addGestureRecognizer:tap];
        [tap setEnabled:NO];
        _tap = tap;
    }
    
    if (!_pan) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        pan.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self.view addGestureRecognizer:pan];
        _pan = pan;
    }
    
}

- (void)viewDidUnload {
    [super viewDidUnload];
    _tap = nil;
    _pan = nil;
}


#pragma mark - UINavigationController push overide  

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    if (!_menuFlags.showingLeftView && !_menuFlags.showingRightView) {
        [super pushViewController:viewController animated:animated];
        return;
    }
     
    if (_menuFlags.showingLeftView) {
        
        // hide the menu, push the view, then slide back
        
        CGRect frame = self.view.frame;
        frame.origin.x = self.view.bounds.size.width;
        [UIView animateWithDuration:.2 animations:^ {
            self.view.frame = frame;        
        } completion:^(BOOL finished) {
            [super pushViewController:viewController animated:NO];
            [self showRootController:YES];
        }];
        
    } else if (_menuFlags.showingRightView) {
        
        // right works a bit different, we'll make a screen shot of the menu overlay, then push, and move everything over
        
        __block CALayer *layer = [CALayer layer];
        CGRect layerFrame = [[UIScreen mainScreen] applicationFrame];
        layerFrame.size.width = kMenuOverlayWidth;
        layer.frame = layerFrame;
        
        UIGraphicsBeginImageContextWithOptions(layerFrame.size, YES, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextTranslateCTM(ctx, -(self.view.frame.size.width-kMenuOverlayWidth), -20.0f);
        [self.view.layer renderInContext:ctx];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        layer.contents = (id)image.CGImage;
        
        [self.view.superview.layer addSublayer:layer];
        layer.cornerRadius = 4.0f;
        layer.shadowOpacity = 0.8f;
        layer.shadowOffset = CGSizeZero;
        layer.shadowRadius = 4.0f;
        layer.shadowPath = [UIBezierPath bezierPathWithRect:layer.bounds].CGPath;
        
        [super pushViewController:viewController animated:NO];
        CGRect frame = self.view.frame;
        frame.origin.x = frame.size.width;
        self.view.frame = frame;
        frame.origin.x = 0.0f;
                
        [UIView animateWithDuration:0.3f animations:^{
            
            self.view.superview.transform = CGAffineTransformMakeTranslation(-[[UIScreen mainScreen] applicationFrame].size.width, 0);
            
        } completion:^(BOOL finished) {
            
            [self showRootController:NO];
            self.view.superview.transform = CGAffineTransformMakeTranslation(0.0f, 0.0f);
            [layer removeFromSuperlayer];

        }];
        
    }
  
}


#pragma mark - GestureRecognizers

- (void)pan:(UIPanGestureRecognizer*)gesture {

    if (gesture.state == UIGestureRecognizerStateBegan) {
        
        [self showShadow:YES];
        _panOriginX = self.view.frame.origin.x;        
        _panVelocity = CGPointMake(0.0f, 0.0f);
        
        if([gesture velocityInView:self.view].x > 0) {
            _panDirection = DDMenuPanDirectionRight;
        } else {
            _panDirection = DDMenuPanDirectionLeft;
        }

    }
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint velocity = [gesture velocityInView:self.view];
        if((velocity.x*_panVelocity.x + velocity.y*_panVelocity.y) < 0) {
            _panDirection = (_panDirection == DDMenuPanDirectionRight) ? DDMenuPanDirectionLeft : DDMenuPanDirectionRight;
        }
        
        _panVelocity = velocity;        
        CGPoint translation = [gesture translationInView:self.view];
        CGRect frame = self.view.frame;
        frame.origin.x = _panOriginX + translation.x;
        
        if (frame.origin.x > 0.0f && !_menuFlags.showingLeftView) {
            
            if(_menuFlags.showingRightView) {
                _menuFlags.showingRightView = NO;
                [self.rightController.view removeFromSuperview];
            }
            
            if (_menuFlags.canShowLeft) {
                
                _menuFlags.showingLeftView = YES;
                [self.view.superview insertSubview:self.leftController.view belowSubview:self.view];
                
            } else {
                frame.origin.x = 0.0f; // ignore right view if it's not set
            }
            
        } else if (frame.origin.x < 0.0f && !_menuFlags.showingRightView) {
            
            if(_menuFlags.showingLeftView) {
                _menuFlags.showingLeftView = NO;
                [self.leftController.view removeFromSuperview];
            }
            
            if (_menuFlags.canShowRight) {
                
                _menuFlags.showingRightView = YES;
                CGRect frame = [[UIScreen mainScreen] applicationFrame];
                frame.size.width -= kMenuOverlayWidth;
                frame.origin.x = kMenuOverlayWidth;
                self.rightController.view.frame = frame;
                [self.view.superview insertSubview:self.rightController.view belowSubview:self.view];
     
            } else {
                frame.origin.x = 0.0f; // ignore left view if it's not set
            }
            
        }
        
        self.view.frame = frame;

    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        
        //  Finishing moving to left, right or root view with current pan velocity
        [self.view setUserInteractionEnabled:NO];
        
        DDMenuPanCompletion completion = DDMenuPanCompletionRoot; // by default animate back to the root
        
        if (_panDirection == DDMenuPanDirectionRight && _menuFlags.showingLeftView) {
            completion = DDMenuPanCompletionLeft;
        } else if (_panDirection == DDMenuPanDirectionLeft && _menuFlags.showingRightView) {
            completion = DDMenuPanCompletionRight;
        }
        
        CGPoint velocity = [gesture velocityInView:self.view];    
        if (velocity.x < 0.0f) {
            velocity.x *= -1.0f;
        }
        BOOL bounce = (velocity.x > 800);
        CGFloat originX = self.view.frame.origin.x;
        CGFloat width = self.view.frame.size.width;
        CGFloat span = (width - kMenuOverlayWidth);
        CGFloat duration = kMenuSlideDuration; // default duration with 0 velocity
        
        
        if (bounce) {
            duration = (span / velocity.x); // bouncing we'll use the current velocity to determine duration
        } else {
            duration = ((span - originX) / span) * duration; // user just moved a little, use the defult duration, otherwise it would be too slow
        }
        
        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            if (completion == DDMenuPanCompletionLeft) {
                [self showLeftController:NO];
            } else if (completion == DDMenuPanCompletionRight) {
                [self showRightController:NO];
            } else {
                [self showRootController:NO];
            }
            [self.view.layer removeAllAnimations];
            [self.view setUserInteractionEnabled:YES];
        }];
        
        CGPoint pos = self.view.layer.position;
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        
        NSMutableArray *keyTimes = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
        NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
        NSMutableArray *timingFunctions = [[NSMutableArray alloc] initWithCapacity:bounce ? 3 : 2];
        
        [values addObject:[NSValue valueWithCGPoint:pos]];
        [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
        [keyTimes addObject:[NSNumber numberWithFloat:0.0f]];
        if (bounce) {
            
            duration += kMenuBounceDuration;
            [keyTimes addObject:[NSNumber numberWithFloat:1.0f - ( kMenuBounceDuration / duration)]];
            if (completion == DDMenuPanCompletionLeft) {
                
                [values addObject:[NSValue valueWithCGPoint:CGPointMake(((width/2) + span) + kMenuBounceOffset, pos.y)]];
                
            } else if (completion == DDMenuPanCompletionRight) {
                
                [values addObject:[NSValue valueWithCGPoint:CGPointMake(-((width/2) - (kMenuOverlayWidth-kMenuBounceOffset)), pos.y)]];
                
            } else {
                
                // depending on which way we're panning add a bounce offset
                if (_panDirection == DDMenuPanDirectionLeft) {
                    [values addObject:[NSValue valueWithCGPoint:CGPointMake((width/2) - kMenuBounceOffset, pos.y)]];
                } else {
                    [values addObject:[NSValue valueWithCGPoint:CGPointMake((width/2) + kMenuBounceOffset, pos.y)]];
                }
                
            }
            
            [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            
        }
        if (completion == DDMenuPanCompletionLeft) {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake((width/2) + span, pos.y)]];
        } else if (completion == DDMenuPanCompletionRight) {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(-((width/2) - kMenuOverlayWidth), pos.y)]];
        } else {
            [values addObject:[NSValue valueWithCGPoint:CGPointMake(width/2, pos.y)]];
        }
        
        [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        [keyTimes addObject:[NSNumber numberWithFloat:1.0f]];
        
        animation.timingFunctions = timingFunctions;
        animation.keyTimes = keyTimes;
        animation.calculationMode = @"cubic";
        animation.values = values;
        animation.duration = duration;   
        animation.removedOnCompletion = NO;
        animation.fillMode = kCAFillModeForwards;
        [self.view.layer addAnimation:animation forKey:nil];
        [CATransaction commit];   
    
    }    
    
}

- (void)tap:(UITapGestureRecognizer*)gesture {
    
    [gesture setEnabled:NO];
    [self showRootController:YES];
    
}


#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {

    // Check for horizontal pan gesture
    if (gestureRecognizer == _pan) {

        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer*)gestureRecognizer;
        CGPoint translation = [panGesture translationInView:self.view];

        if ([panGesture velocityInView:self.view].x < 600 && sqrt(translation.x * translation.x) / sqrt(translation.y * translation.y) > 1) {
            return YES;
        } 
        
        return NO;
    }

    return YES;
   
}


#pragma Internal Nav Handling 

- (void)showShadow:(BOOL)val {

    self.view.layer.shadowOpacity = val ? 0.8f : 0.0f;
    if (val) {
        self.view.layer.cornerRadius = 4.0f;
        self.view.layer.shadowOffset = CGSizeZero;
        self.view.layer.shadowRadius = 4.0f;
        self.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.view.bounds].CGPath;
    }
    
}

- (void)showRootController:(BOOL)animated {
    
    [_tap setEnabled:NO];
    
    CGRect frame = self.view.frame;
    frame.origin.x = 0.0f;
    if (!animated) {
        self.view.frame = frame;
        return;
    }
    
    [UIView animateWithDuration:.3 animations:^{
        
        self.view.frame = frame;
        
    } completion:^(BOOL finished) {
        
        if (self.leftController && self.leftController.view.superview) {
            [self.leftController.view removeFromSuperview];
        }
        
        if (self.rightController && self.rightController.view.superview) {
            [self.rightController.view removeFromSuperview];
        }
        
        _menuFlags.showingLeftView = NO;
        _menuFlags.showingRightView = NO;

        [self showShadow:NO];
        
    }];
    
}

- (void)showLeftController:(BOOL)animated {
    if (!_menuFlags.canShowLeft) return;
    
    if (_menuFlags.respondsToWillShowViewController) {
        [self.delegate menuController:self willShowViewController:self.leftController];
    }
    _menuFlags.showingLeftView = YES;
    [self showShadow:YES];

    UIView *view = self.leftController.view;
    view.frame = [[UIScreen mainScreen] applicationFrame];
    [self.view.superview insertSubview:view belowSubview:self.view];
    
    CGRect frame = self.view.frame;
    frame.origin.x = (CGRectGetMaxX(view.frame) - kMenuOverlayWidth);
    
    if (!animated) {
        self.view.frame = frame;
        [_tap setEnabled:YES];
        return;
    }
    
    [UIView animateWithDuration:.3 animations:^{
        self.view.frame = frame;
    } completion:^(BOOL finished) {
        [_tap setEnabled:YES];
    }];
    
}

- (void)showRightController:(BOOL)animated {
    if (!_menuFlags.canShowRight) return;
    
    if (_menuFlags.respondsToWillShowViewController) {
        [self.delegate menuController:self willShowViewController:self.rightController];
    }
    _menuFlags.showingRightView = YES;
    [self showShadow:YES];
    
    UIView *view = self.rightController.view;
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    frame.origin.x = kMenuOverlayWidth;
    frame.size.width -= kMenuOverlayWidth;
    view.frame = frame;
    [self.view.superview insertSubview:view belowSubview:self.view];
    
    frame = self.view.frame;
    frame.origin.x = -(frame.size.width - kMenuOverlayWidth);
    
    if (!animated) {
        self.view.frame = frame;
        [_tap setEnabled:YES];
        return;
    }
    
    [UIView animateWithDuration:.3 animations:^{
        self.view.frame = frame;
    } completion:^(BOOL finished) {
        [_tap setEnabled:YES];
    }];
}


#pragma mark Setters

- (void)setDelegate:(id<DDMenuControllerDelegate>)val {
    [super setDelegate:(id<UINavigationControllerDelegate>)val];
    
    _menuFlags.respondsToWillShowViewController = [(id)self.delegate respondsToSelector:@selector(menuController:willShowViewController:)];
    
}

- (void)setRightController:(UIViewController *)rightController {
    _right = rightController;
    
    NSAssert([self.viewControllers count] > 0, @"Must have a root controller set.");
    
    UIViewController *controller = [self.viewControllers objectAtIndex:0];
    
    if (_right) {
            
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showRight:)];
        controller.navigationItem.rightBarButtonItem = button;
        _menuFlags.canShowRight = YES;

        
    } else {
            
        controller.navigationItem.rightBarButtonItem = nil;
        _menuFlags.canShowRight = NO;

    }
    
}

- (void)setLeftController:(UIViewController *)leftController {
    _left = leftController;
    
    NSAssert([self.viewControllers count] > 0, @"Must have a root controller set.");
    
    UIViewController *controller = [self.viewControllers objectAtIndex:0];
    
    if (_left) {
        
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showLeft:)];
        controller.navigationItem.leftBarButtonItem = button;
        _menuFlags.canShowLeft = YES;

        
    } else {
        
        controller.navigationItem.leftBarButtonItem = nil;
        _menuFlags.canShowLeft = NO;

    }
    
    
}


#pragma mark - Actions 

- (void)showLeft:(id)sender {
    
    [self showLeftController:YES];
    
}

- (void)showRight:(id)sender {
    
    [self showRightController:YES];
    
}

@end
