//
// Created by Joe Walnes on 6/28/14.
// Copyright (c) 2014 Sneaky Squid. All rights reserved.
//

#import "SSCameraLockView.h"

#define PointFromOrigin(origin, radius, angle) CGPointMake(origin.x + radius * cosf(angle), origin.y + radius * sinf(angle))

static const NSTimeInterval kShowHideAnimationDuration = 0.1;
static const CGFloat mainSize = 100.0f;
static const CGFloat margin = 10.0f;
static const CGFloat mainSizeWithMargin = mainSize + margin * 2.0f;
static const CGFloat labelPadding = 4.0f;

@implementation SSCameraLockView {
    BOOL _active;
}

- (void)show:(CGPoint)center {
    CGSize size = CGSizeMake(mainSizeWithMargin, mainSizeWithMargin);

    CGRect newFrame = CGRectMake(
            center.x - size.width / 2.0f,
            center.y - size.height / 2.0f,
            size.width,
            size.height);

    if (!_active) {
        self.hidden = NO;
        self.frame = CGRectMake(center.x, center.y, 0.0f, 0.0f);
        _active = YES;
    }

    [UIView animateWithDuration:kShowHideAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.frame = newFrame;
    } completion:nil];
}

- (void)setAdjusting:(BOOL)adjusting {
    [self willChangeValueForKey:@"adjusting"];
    _adjusting = adjusting;
    [self didChangeValueForKey:@"adjusting"];
}

- (void)hide {
    if (_active) {
        [UIView animateWithDuration:kShowHideAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.frame = CGRectMake(self.frame.origin.x + self.frame.size.width / 2.0f, self.frame.origin.y + self.frame.size.height / 2.0f, 0.0f, 0.0f);
        } completion:^(BOOL finished) {
            if (finished) {
                self.hidden = YES;
            }
        }];
        _active = NO;
    }
}

- (CALayer *)createLabel:(NSString *)text withColor:(CGColorRef)color withAlignment:(NSString *const)alignment {
    UIFont *labelFont = [UIFont systemFontOfSize:8.0f];
    CGRect labelRect = CGRectMake(labelPadding, 0, mainSizeWithMargin - labelPadding * 2.0f, margin);
    CGRect labelBounds = [text boundingRectWithSize:labelRect.size
                                            options:0
                                         attributes:@{NSFontAttributeName : labelFont}
                                            context:nil];
    CALayer *labelBgLayer = [CALayer layer];
    labelBgLayer.cornerRadius = 5.0f;
    if ([alignment isEqual:kCAAlignmentLeft]) {
        labelBgLayer.frame = CGRectMake(
                labelRect.origin.x - labelPadding,
                labelRect.origin.y,
                labelBounds.size.width + labelPadding * 2.0f,
                labelBounds.size.height);
    } else {
        labelBgLayer.frame = CGRectMake(
                mainSizeWithMargin - (labelBounds.size.width + labelPadding * 2.0f),
                labelRect.origin.y,
                labelBounds.size.width + labelPadding * 2.0f,
                labelBounds.size.height);
    }
    labelBgLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4].CGColor;

    CATextLayer *labelTextLayer = [[CATextLayer alloc] init];
    labelTextLayer.contentsScale = [[UIScreen mainScreen] scale];
    labelTextLayer.font = CFBridgingRetain(labelFont.fontName);
    labelTextLayer.fontSize = labelFont.pointSize;
    labelTextLayer.frame = labelRect;
    labelTextLayer.string = text;
    labelTextLayer.alignmentMode = alignment;
    labelTextLayer.foregroundColor = color;

    CALayer *layer = [CALayer layer];
    layer.frame = CGRectMake(0, 0, mainSizeWithMargin, mainSizeWithMargin);
    layer.anchorPoint = CGPointMake(0.5f, 0.5f);

    [layer addSublayer:labelBgLayer];
    [layer addSublayer:labelTextLayer];

    return layer;
}

- (void)transformContents:(CGAffineTransform)transform {
}
@end


@implementation SSCameraFocusLockView {
    CALayer *_ringLayer;
    CALayer *_labelLayer;
}

+ (id)view {
    return [[SSCameraFocusLockView alloc] initWithFrame:CGRectMake(0, 0, mainSizeWithMargin, mainSizeWithMargin)];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.hidden = YES;

        CGRect mainRect = CGRectMake(margin, margin, mainSize, mainSize);
        UIBezierPath *ringPath = [self createFocusRingInRect:mainRect];

        _ringLayer = [CALayer layer];
        _ringLayer.frame = frame;

        CAShapeLayer *ringBgLayer = [CAShapeLayer layer];
        ringBgLayer.frame = frame;
        ringBgLayer.fillColor = [UIColor clearColor].CGColor;
        ringBgLayer.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.4].CGColor;
        ringBgLayer.lineWidth = 3;
        ringBgLayer.path = ringPath.CGPath;
        ringBgLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        [_ringLayer addSublayer:ringBgLayer];

        CAShapeLayer *ringFgLayer = [CAShapeLayer layer];
        ringFgLayer.frame = frame;
        ringFgLayer.fillColor = [UIColor clearColor].CGColor;
        ringFgLayer.strokeColor = [UIColor colorWithRed:179.0f / 255.0f
                                                  green:255.0f / 255.0f
                                                   blue:232.0f / 255.0f
                                                  alpha:0.9f].CGColor;
        ringFgLayer.lineWidth = 1;
        ringFgLayer.path = ringPath.CGPath;
        ringFgLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        [_ringLayer addSublayer:ringFgLayer];

        _labelLayer = [self createLabel:@"Focus" withColor:ringFgLayer.strokeColor withAlignment:kCAAlignmentLeft];
        [self.layer addSublayer:_labelLayer];
        [self.layer addSublayer:_ringLayer];
    }
    return self;
}

- (void)transformContents:(CGAffineTransform)transform {
    _labelLayer.affineTransform = transform;
}

- (UIBezierPath *)createFocusRingInRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;

    CGPoint center = CGPointMake(rect.origin.x + rect.size.width / 2.0f, rect.origin.y + rect.size.height / 2.0f);
    CGFloat ringRadius = 44.0f;
    CGFloat innerRadius = 48.0f;
    CGFloat outerRadius = 50.0f;
    int numberOfLumps = 40;

    CGFloat lumpAngle = (CGFloat) M_PI / (CGFloat) numberOfLumps * 2.0f;

    [path moveToPoint:PointFromOrigin(center, innerRadius, 0.0f)];
    for (int lump = 0; lump < numberOfLumps; lump++) {
        CGFloat lumpStartAngle = lumpAngle * (CGFloat) lump;
        CGFloat lumpMidAngle = lumpStartAngle + lumpAngle / 2.0f;
        CGFloat lumpEndAngle = lumpStartAngle + lumpAngle;

        [path addCurveToPoint:PointFromOrigin(center, outerRadius, lumpMidAngle)
                controlPoint1:PointFromOrigin(center, innerRadius, lumpMidAngle)
                controlPoint2:PointFromOrigin(center, outerRadius, lumpStartAngle)];
        [path addCurveToPoint:PointFromOrigin(center, innerRadius, lumpEndAngle)
                controlPoint1:PointFromOrigin(center, outerRadius, lumpEndAngle)
                controlPoint2:PointFromOrigin(center, innerRadius, lumpMidAngle)];
    }
    [path closePath];

    [path moveToPoint:PointFromOrigin(center, ringRadius, 0.0f)];
    [path addArcWithCenter:center radius:ringRadius startAngle:0 endAngle:(CGFloat) M_PI * 2.0f clockwise:YES];
    [path closePath];

    return path;
}

- (void)setAdjusting:(BOOL)adjusting {
    [super setAdjusting:adjusting];

    CGFloat currentAngle = [(NSNumber *) [_ringLayer.presentationLayer valueForKeyPath:@"transform.rotation.z"] floatValue];
    CABasicAnimation *animation = (CABasicAnimation *) [_ringLayer animationForKey:@"adjustingAnimation"];
    if (adjusting) {
        if (animation == nil) {
            animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            animation.fromValue = @(currentAngle);
            animation.toValue = @(currentAngle + 2 * M_PI);
            animation.duration = 6.0f;
            animation.repeatCount = HUGE_VALF;
            [_ringLayer addAnimation:animation forKey:@"adjustingAnimation"];
        }
    } else {
        if (animation != nil) {
            [_ringLayer removeAnimationForKey:@"adjustingAnimation"];
            _ringLayer.affineTransform = CGAffineTransformMakeRotation(currentAngle);
        }
    }
}

@end

@implementation SSCameraExposureLockView {
    CALayer *_apertureLayer;
    CAShapeLayer *_apertureBgLayer;
    CAShapeLayer *_apertureFgLayer;
    UIBezierPath *_ringPathOpen;
    UIBezierPath *_ringPathClose;
    CALayer *_labelLayer;
}

+ (id)view {
    return [[SSCameraExposureLockView alloc] initWithFrame:CGRectMake(0, 0, mainSizeWithMargin, mainSizeWithMargin)];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.hidden = YES;

        CGRect mainRect = CGRectMake(margin, margin, mainSize, mainSize);
        _ringPathOpen = [self createApertureInRect:mainRect withThickness:4.0f];
        _ringPathClose = [self createApertureInRect:mainRect withThickness:10.0f];

        _apertureLayer = [CALayer layer];
        _apertureLayer.frame = frame;

        _apertureBgLayer = [CAShapeLayer layer];
        _apertureBgLayer.frame = frame;
        _apertureBgLayer.fillColor = [UIColor clearColor].CGColor;
        _apertureBgLayer.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.4].CGColor;
        _apertureBgLayer.lineWidth = 3;
        _apertureBgLayer.path = _ringPathOpen.CGPath;
        _apertureBgLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        [_apertureLayer addSublayer:_apertureBgLayer];

        _apertureFgLayer = [CAShapeLayer layer];
        _apertureFgLayer.frame = frame;
        _apertureFgLayer.fillColor = [UIColor clearColor].CGColor;
        _apertureFgLayer.strokeColor = [UIColor colorWithRed:255.0f / 255.0f
                                                       green:212.0f / 255.0f
                                                        blue:138.0f / 255.0f
                                                       alpha:0.9f].CGColor;

        _apertureFgLayer.lineWidth = 1;
        _apertureFgLayer.path = _ringPathOpen.CGPath;
        _apertureFgLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        [_apertureLayer addSublayer:_apertureFgLayer];

        _labelLayer = [self createLabel:@"Exposure" withColor:_apertureFgLayer.strokeColor withAlignment:kCAAlignmentRight];
        [self.layer addSublayer:_labelLayer];
        [self.layer addSublayer:_apertureLayer];
    }
    return self;
}

- (void)transformContents:(CGAffineTransform)transform {
    _labelLayer.affineTransform = transform;
}

- (UIBezierPath *)createApertureInRect:(CGRect)rect withThickness:(CGFloat)thickness {
    UIBezierPath *path = [UIBezierPath bezierPath];
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;

    CGPoint center = CGPointMake(rect.origin.x + rect.size.width / 2.0f, rect.origin.y + rect.size.height / 2.0f);

    CGFloat ringRadius = 42.0f;
    CGFloat apertureRadius = ringRadius - thickness;
    int numberOfBlades = 8;

    CGFloat bladeAngle = (CGFloat) M_PI / (CGFloat) numberOfBlades * 2.0f;
    for (int blade = 0; blade < numberOfBlades; blade++) {
        CGFloat bladeMidAngle = bladeAngle * (CGFloat) blade;
        CGFloat bladeStartAngle = bladeMidAngle + bladeAngle / 2.0f;
        CGFloat bladeMidRadius = cosf(bladeAngle / 2.0f) * apertureRadius;
        CGPoint bladeStart = PointFromOrigin(center, apertureRadius, bladeStartAngle);
        CGPoint bladeEnd = PointFromOrigin(center, ringRadius, bladeMidAngle - acosf(bladeMidRadius / ringRadius));

        [path moveToPoint:bladeStart];
        [path addLineToPoint:bladeEnd];
    }
    [path closePath];

    [path moveToPoint:PointFromOrigin(center, ringRadius, 0.0f)];
    [path addArcWithCenter:center radius:ringRadius startAngle:0 endAngle:(CGFloat) M_PI * 2.0f clockwise:YES];
    [path closePath];

    return path;
}

- (void)setAdjusting:(BOOL)adjusting {
    [super setAdjusting:adjusting];

    CGPathRef currentPath = (__bridge CGPathRef) [_apertureFgLayer.presentationLayer valueForKeyPath:@"path"];
    CABasicAnimation *animation = (CABasicAnimation *) [_apertureFgLayer animationForKey:@"adjustingAnimation"];
    if (adjusting) {
        if (animation == nil) {
            animation = [CABasicAnimation animationWithKeyPath:@"path"];
            animation.duration = 0.4f;
            animation.fromValue = (id) (_ringPathOpen.CGPath);
            animation.toValue = (id) (_ringPathClose.CGPath);
            animation.repeatCount = HUGE_VALF;
            animation.autoreverses = YES;
            animation.fillMode = kCAFillModeForwards;
            [_apertureFgLayer addAnimation:animation forKey:@"adjustingAnimation"];
            [_apertureBgLayer addAnimation:animation forKey:@"adjustingAnimation"];
        }
    } else {
        if (animation != nil) {
            [_apertureFgLayer removeAnimationForKey:@"adjustingAnimation"];
            [_apertureBgLayer removeAnimationForKey:@"adjustingAnimation"];

            CABasicAnimation *resetAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
            resetAnimation.duration = 0.2f;
            resetAnimation.fromValue = (__bridge id) currentPath;
            resetAnimation.toValue = (id) (_ringPathOpen.CGPath);
            resetAnimation.fillMode = kCAFillModeForwards;
            [_apertureFgLayer addAnimation:resetAnimation forKey:@"resetAnimation"];
            [_apertureBgLayer addAnimation:resetAnimation forKey:@"resetAnimation"];
        }
    }
}

@end
