#import "IndoorControl.h"

#include "UIColors.h"
#include "UIHelpers.h"
#include "ImageHelpers.h"
#include "UIHelpers.h"
#include "InteriorsExplorerFloorItemView.h"

#import "ImmediatePanGestureRecognizer.h"
#import "UIButton+DefaultStates.h"
#import "UIView+TouchExclusivity.h"
#import <QuartzCore/QuartzCore.h>

namespace
{
    float iPhoneDismissButtonMargin = 28.f;
    float buttonSize = 20.0f;
    float buttonViewSize = 35.0f;
}


@implementation IndoorControl

- (UIColor*) textColorNormal
{
    return [UIColor colorWithRed:(18.0f/255.0f) green:(86.0f/255.0f) blue:(176.0f/255.0f) alpha:1.0f];
}

- (UIColor*) textColorHighlighted
{
    return [UIColor colorWithRed:(205.0f/255.0f) green:(252.0f/255.0f) blue:(13.0f/255.0f) alpha:1.0f];;
}

- (id) initWithParams:(float)width :(float)height andDelegate:(id<IndoorControlDelegate>)delegate
{
    if (self = [super init])
    {
        m_delegate = delegate;
        
        const bool isPhone = ExampleApp::Helpers::UIHelpers::UsePhoneLayout();

        m_screenWidth = width;
        m_screenHeight = height;

        m_stateChangeAnimationTimeSeconds = 0.2f;

        self.frame = CGRectMake(0,
                                0,
                                m_screenWidth,
                                m_screenHeight);


        m_inactiveFloorListXPosition = m_screenWidth;

        const float upperMargin = isPhone ? 20.0f : 50.0f;
        m_inactiveDetailPaneYPosition = m_screenHeight;


        self.pFloorPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 110, 200)];
        [self addSubview:self.pFloorPanel];
        
        NSBundle* widgetsBundle = [NSBundle bundleForClass:[IndoorControl class]];

        self.pFloorListArrowDown = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"images/arrow3_down" inBundle:widgetsBundle compatibleWithTraitCollection:nil]];
        self.pFloorListArrowUp = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"images/arrow3_up" inBundle:widgetsBundle compatibleWithTraitCollection:nil]];

        [self.pFloorPanel addSubview:self.pFloorListArrowDown];
        [self.pFloorPanel addSubview:self.pFloorListArrowUp];

        self.pFloorListView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 110, 200) style:UITableViewStylePlain];
        self.pFloorListView.delegate = self;
        self.pFloorListView.dataSource = self;
        self.pFloorListView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.pFloorListView.backgroundColor = [UIColor clearColor];
        self.pFloorListView.backgroundView = nil;
        self.pFloorListView.autoresizesSubviews = YES;
        self.pFloorListView.scrollEnabled = NO;

        [self.pFloorPanel addSubview:self.pFloorListView];

        self.pFloorChangeButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        [self.pFloorChangeButton setBackgroundImage:ExampleApp::Helpers::ImageHelpers::LoadImage(@"images/floor_selection_button", widgetsBundle) forState:UIControlStateNormal];
        [self.pFloorChangeButton setBackgroundImage:ExampleApp::Helpers::ImageHelpers::LoadImage(@"images/floor_selection_button_down", widgetsBundle) forState:UIControlStateSelected];
        m_draggingFloorButton = NO;

        ImmediatePanGestureRecognizer* buttonDrag = [[ImmediatePanGestureRecognizer alloc] initWithTarget:self action:@selector(dragButton:)];
        [self.pFloorChangeButton addGestureRecognizer:buttonDrag];


        [self.pFloorPanel addSubview:self.pFloorChangeButton];

        const float upperPadding = 3.0f;
        self.pFloorOnButtonLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, upperPadding, 64, 64-upperPadding)];
        self.pFloorOnButtonLabel.lineBreakMode = NSLineBreakByClipping;
        self.pFloorOnButtonLabel.adjustsFontSizeToFitWidth = NO;
        self.pFloorOnButtonLabel.textColor = [UIColor whiteColor];
        self.pFloorOnButtonLabel.textAlignment = NSTextAlignmentCenter;
        self.pFloorOnButtonLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        self.pFloorOnButtonLabel.userInteractionEnabled = NO;
        [self.pFloorChangeButton addSubview:self.pFloorOnButtonLabel];


        const float labelLength = isPhone ? fminf(200.f, m_screenWidth*0.5f) : 315.f;

        const float detailsPanelHeight = 50.0f;
        float totalPanelLength = labelLength;

        float totalPanelHeight = detailsPanelHeight;

        m_detailsPanelHeight = totalPanelHeight;

        self.pDetailsPanel = [[UIView alloc] initWithFrame:CGRectMake(m_screenWidth * 0.5f - totalPanelLength * 0.5f, upperMargin, totalPanelLength, totalPanelHeight)];

        UIColor* dismissButtonBackgroundColor = ExampleApp::Helpers::ColorPalette::White;

        UIView* dismissButtonParent = self;
        self.pDismissButtonBackground = [[UIImageView alloc] initWithImage:ExampleApp::Helpers::ImageHelpers::ImageFromColor(dismissButtonBackgroundColor)];
        self.pDismissButtonBackground.frame = CGRectMake(55 - buttonViewSize/2, 0, buttonViewSize, buttonViewSize);
        self.pDismissButtonBackground.userInteractionEnabled = YES;
        [dismissButtonParent addSubview:self.pDismissButtonBackground];

        self.pDismissButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, buttonSize, buttonSize)];
        self.pDismissButton.center = CGPointMake(self.pDismissButtonBackground.frame.size.width  / 2,
                                                 self.pDismissButtonBackground.frame.size.height / 2);
        [self.pDismissButton setDefaultStatesWithImageNames:@"images/button_exit_interior_off" :@"images/button_exit_interior_off" fromBundle:widgetsBundle];
        [self.pDismissButton setDefaultStatesWithColors:  ExampleApp::Helpers::ColorPalette::White: ExampleApp::Helpers::ColorPalette::White];

        [self.pDismissButton addTarget:self action:@selector(onCancelButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.pDismissButtonBackground addSubview:self.pDismissButton];

        UIColor* detailsPanelBackgroundColor = [UIColor blackColor];

        self.pDetailsPanelBackground = [[UIImageView alloc] initWithImage:ExampleApp::Helpers::ImageHelpers::ImageFromColor(detailsPanelBackgroundColor)];
        self.pDetailsPanelBackground.frame = CGRectMake(0, 0, labelLength, detailsPanelHeight);
        self.pDetailsPanelBackground.alpha = 0.5f;

        [self.pDetailsPanel addSubview:self.pDetailsPanelBackground];

        const float textPadding = 14.f;

        self.pFloorNameLabel = [[UILabel alloc] initWithFrame:CGRectMake( textPadding, textPadding, labelLength - (2*textPadding), detailsPanelHeight - (2*textPadding))];
        self.pFloorNameLabel.textColor = [UIColor whiteColor];
        self.pFloorNameLabel.textAlignment = NSTextAlignmentCenter;
        [self.pFloorNameLabel setHidden:true];
        [self.pDetailsPanel addSubview:self.pFloorNameLabel];
        [self.pDetailsPanel setHidden:true];
        [self addSubview:self.pDetailsPanel];

        self.pDetailsPanel.alpha = 0.0f;

        m_onScreenParam = 0.f;
        m_touchEnabled = NO;
        m_floorSelectionEnabled = NO;

        m_floorDivisionHeight = m_screenHeight*0.0625f;
        m_halfDivisionHeight = m_floorDivisionHeight/2.0f;
        m_halfButtonHeight=static_cast<float>(self.pFloorChangeButton.frame.size.height/2.0f);

        m_isSliderAnimPlaying = false;

        [self hideFloorLabels];
        [self setHidden:YES];
        [self setArrowState:NO :NO];
    }

    return self;
}

- (void)layoutSubviews
{
    CGFloat panelHeight = self.pFloorPanel.frame.size.height;

    CGRect floorButtonFrame = self.pFloorChangeButton.frame;
    self.pFloorChangeButton.frame = CGRectMake(self.pFloorPanel.frame.size.width*0.5f - floorButtonFrame.size.width*0.5f,
                                               panelHeight - floorButtonFrame.size.height,
                                               floorButtonFrame.size.width,
                                               floorButtonFrame.size.height);
    
    // Bug before iOS10 makes all UITableView(Cell)s always have a white background. (http://stackoverflow.com/questions/27551291/uitableview-backgroundcolor-always-white-on-ipad)
    // None of the other solutions appear to work.
    self.pFloorListView.backgroundColor = [UIColor clearColor];
    for (UITableViewCell* cell in self.pFloorListView.visibleCells)
    {
        cell.backgroundColor = [UIColor clearColor];
    }
}

- (void)dealloc
{
    [self removeFromSuperview];
}

- (void) show
{
    [self setHidden:NO];
}

- (void) hide
{
    [self setHidden:YES];
}

- (void) onCancelButtonPressed:(UIButton *)sender
{
    [m_delegate onCancelButtonPressed];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if(!m_touchEnabled)
    {
        return nil;
    }

    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) return nil;
    return hitView;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if(!m_touchEnabled)
    {
        return NO;
    }

    if(m_floorSelectionEnabled && m_draggingFloorButton)
    {
        return YES;
    }

    CGPoint touchLocation = point;
    CGPoint floorPanelLocation = [self convertPoint:touchLocation toView:self.pFloorPanel];
    if (CGRectContainsPoint(self.pFloorChangeButton.frame, floorPanelLocation) && m_floorSelectionEnabled)
        return YES;
    if (CGRectContainsPoint(self.pDetailsPanel.frame, touchLocation))
        return YES;
    if (CGRectContainsPoint(self.pDismissButtonBackground.frame, touchLocation))
        return YES;
    return  NO;
}

- (BOOL)consumesTouch:(UITouch *)touch
{
    CGPoint touchLocation = [touch locationInView:self];
    return [self pointInside:touchLocation withEvent:nil];
}

- (void) setFloorName:(NSString*)name
{
    self.pFloorNameLabel.text = name;
}

- (void) setSelectedFloor:(int)floorIndex
{
    [self refreshFloorIndicator:floorIndex];

    if(!m_draggingFloorButton)
    {
        [self moveButtonToFloorIndex:floorIndex :YES];
    }
}

- (void) updateFloors: (NSArray<NSString*>*) floorShortNames withCurrentFloor: (int) currentlySelectedFloorIndex;
{
    m_floorSelection = 0.0;
    m_tableViewFloorNames = [[floorShortNames reverseObjectEnumerator] allObjects];

    [self refreshFloorViews];

    [self setNeedsLayout];
    [self layoutIfNeeded];

    [self refreshFloorIndicator:currentlySelectedFloorIndex];
    [self moveButtonToFloorIndex:currentlySelectedFloorIndex :NO];
}

- (void) refreshFloorViews
{
    [self.pFloorListView reloadData];


    int floorCount = [m_tableViewFloorNames count];
    float maxHeight = m_screenHeight*0.5f;
    float verticalPadding = ((float)self.pFloorChangeButton.frame.size.height - m_floorDivisionHeight);
    float totalHeight = m_floorDivisionHeight * floorCount + verticalPadding;
    if(totalHeight > maxHeight)
    {
        totalHeight = maxHeight;
    }

    CGRect floorPanelFrame = self.pFloorPanel.frame;
    const float floorPanelVerticalCenterline = 0.54f;
    floorPanelFrame.origin.y = m_screenHeight*floorPanelVerticalCenterline - totalHeight*0.5f;
    floorPanelFrame.size.height = totalHeight;
    self.pFloorPanel.frame = floorPanelFrame;
    self.pFloorListView.frame = CGRectMake(0, verticalPadding/2, floorPanelFrame.size.width, floorPanelFrame.size.height-(verticalPadding));
    CGRect dismissButtonFrame = self.pDismissButtonBackground.frame;
    const float dismissButtonSpacing = 10.f;
    dismissButtonFrame.origin.y = (self.pFloorPanel.frame.origin.y - dismissButtonSpacing) - dismissButtonFrame.size.height;
    self.pDismissButtonBackground.frame = dismissButtonFrame;

    m_floorSelectionEnabled= (floorCount > 1);
    self.pFloorPanel.hidden = !m_floorSelectionEnabled;
    self.pFloorPanel.userInteractionEnabled = self.pFloorChangeButton.userInteractionEnabled = m_floorSelectionEnabled;

    m_floorSelectionEnabled= (floorCount > 1);
    self.pFloorPanel.hidden = !m_floorSelectionEnabled;
    self.pFloorPanel.userInteractionEnabled = self.pFloorChangeButton.userInteractionEnabled = m_floorSelectionEnabled;

    const CGFloat arrowWidth=20.0f;
    const CGFloat arrowHeight=verticalPadding*0.5f;
    self.pFloorListArrowUp.frame = CGRectMake(self.pFloorPanel.frame.size.width/2 - arrowWidth/2, self.pFloorListView.frame.origin.y-arrowHeight, arrowWidth, arrowHeight);
    self.pFloorListArrowDown.frame = CGRectMake(self.pFloorPanel.frame.size.width/2 - arrowWidth/2, self.pFloorListView.frame.origin.y+self.pFloorListView.frame.size.height, arrowWidth, arrowHeight);

    [self refreshArrowState];
}

- (void) playSliderShakeAnim
{
    CGFloat xPos = [self GetXPositionForFloorPanelAt:1.0];

    CGFloat posLeft = xPos - 5.0f;
    CGFloat posRight = xPos + 10.0f;

    m_isSliderAnimPlaying = true;

    [UIView animateWithDuration:1.1 delay:0.0 usingSpringWithDamping:0.3f initialSpringVelocity:0.2f options:UIViewKeyframeAnimationOptionCalculationModeCubicPaced animations:^{

        [UIView animateKeyframesWithDuration:0.1 delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeCubicPaced animations:^{
            CGRect floorFrame = self.pFloorPanel.frame;
            floorFrame.origin.x = posLeft;
            self.pFloorPanel.frame = floorFrame;
        } completion:nil];

        [UIView animateKeyframesWithDuration:0.1 delay:0.1 options:UIViewKeyframeAnimationOptionCalculationModeCubicPaced animations:^{
            CGRect floorFrame = self.pFloorPanel.frame;
            floorFrame.origin.x = posRight;
            self.pFloorPanel.frame = floorFrame;
        } completion:nil];

        [UIView animateKeyframesWithDuration:0.15 delay:0.2 options:UIViewKeyframeAnimationOptionCalculationModeCubicPaced animations:^{
            CGRect floorFrame = self.pFloorPanel.frame;
            floorFrame.origin.x = xPos;
            self.pFloorPanel.frame = floorFrame;
        } completion:nil];

    } completion:^(BOOL finished){
        m_isSliderAnimPlaying = false;
    }];
}

- (bool) GetCanShowChangeFloorTutorialDialog
{
    int floorCount = [m_tableViewFloorNames count];
    return floorCount > 1;
}

- (void) refreshFloorIndicator:(int)floorIndex
{
    int nameIndex = [m_tableViewFloorNames count] - 1 - floorIndex;
    self.pFloorOnButtonLabel.text = m_tableViewFloorNames[nameIndex];
}

- (float) GetXPositionForFloorPanelAt:(float)t
{
    float openX = iPhoneDismissButtonMargin + (0.5f * self.pDismissButtonBackground.frame.size.width + 0.5f * self.pFloorPanel.frame.size.width);
    return m_screenWidth - t * openX;
}

- (float) GetXPositionForDismissButtonAt:(float)t
{
    return m_screenWidth - t * (iPhoneDismissButtonMargin + self.pDismissButtonBackground.frame.size.width);
}

- (void) setFullyOnScreen
{
    [self animateTo:1.0f];
}

- (void) setFullyOffScreen
{
    [self animateTo:0.0f];
}

- (void) setOnScreenStateToIntermediateValue:(float)onScreenState
{

    CGRect floorPanel = self.pFloorPanel.frame;
    floorPanel.origin.x = [self GetXPositionForFloorPanelAt :onScreenState];

    CGRect dismissPanel = self.pDismissButtonBackground.frame;
    dismissPanel.origin.x = [self GetXPositionForDismissButtonAt:onScreenState];

    self.pDismissButtonBackground.frame = dismissPanel;

    self.hidden = onScreenState == 0.0f;
    self.pFloorPanel.frame = floorPanel;

    self.pDetailsPanel.alpha = onScreenState;
    m_onScreenParam = onScreenState;
}

- (void) animateTo:(float)t
{
    CGRect floorFrame = self.pFloorPanel.frame;
    floorFrame.origin.x = [self GetXPositionForFloorPanelAt:t];

    CGRect dismissButtonFrame = self.pDismissButtonBackground.frame;

    dismissButtonFrame.origin.x = [self GetXPositionForDismissButtonAt:t];

    bool isOnScreenAnim = false;

    if(t > 0.f)
    {
        self.hidden = false;
        isOnScreenAnim = true;
    }

    [UIView animateWithDuration:m_stateChangeAnimationTimeSeconds
                          delay:0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^
     {
         self.pDetailsPanel.alpha = t;
     }
                     completion:^(BOOL finished)
     {
         self.hidden = (t == 0.0f);
         m_onScreenParam = t;
     }
     ];

    [UIView animateWithDuration:m_stateChangeAnimationTimeSeconds
                          delay:isOnScreenAnim ? 1.0f : 0.0f
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^
     {
//         self.pFloorPanel.frame = CGRectMake(0, 0, 110, 200);
//         self.pDismissButtonBackground.frame = CGRectMake(0, 0, buttonViewSize, buttonViewSize);
     }
                     completion:^(BOOL FINISHED)
     {
         if (!isOnScreenAnim)
         {
             [self.pTimer invalidate];
             self.pTimer = nil;
         }
     }];
}

- (void) setTouchEnabled:(BOOL)enabled
{
    m_touchEnabled = enabled;
}

- (CGFloat) getScrollSpeed:(CGFloat)t
{
    const float maxScrollSpeed=15.0f;

    t = MAX(-1, MIN(1,t));
    return t*ABS(t)*maxScrollSpeed;
}

- (void) refreshArrowState
{
    [self setArrowState:self.pFloorListView.contentOffset.y>0
                       :self.pFloorListView.contentOffset.y<self.pFloorListView.contentSize.height-self.pFloorListView.bounds.size.height];
}

- (void) setArrowState:(BOOL)showUp :(BOOL)showDown
{
    self.pFloorListArrowUp.hidden = !showUp;
    self.pFloorListArrowDown.hidden = !showDown;
}

- (void) step
{
    if(!m_draggingFloorButton)
    {
        return;
    }

    float scrollDelta = 0.0f;
    const float joystickScrollThresholdDistance = 0.25f;


    if(m_floorButtonParameter <= joystickScrollThresholdDistance)
    {
        float localT = m_floorButtonParameter/joystickScrollThresholdDistance;
        scrollDelta = [self getScrollSpeed:(1.0f - localT)];
    }
    else if(m_floorButtonParameter >= 1.0f-joystickScrollThresholdDistance)
    {
        float localT = (m_floorButtonParameter-(1.0f-joystickScrollThresholdDistance))/joystickScrollThresholdDistance;
        scrollDelta = [self getScrollSpeed:-localT];
    }

    m_scrollRect.origin.y += scrollDelta;
    [self.pFloorListView scrollRectToVisible:m_scrollRect animated:NO];

    CGPoint localButtonCenter = CGPointMake(0.0f, m_halfButtonHeight);
    CGPoint pointInTable = [self.pFloorChangeButton convertPoint:localButtonCenter toView:self.pFloorListView];
    m_floorSelection = 1.0f - static_cast<float>((pointInTable.y-m_halfDivisionHeight)/(self.pFloorListView.contentSize.height-m_floorDivisionHeight));
    
    [m_delegate onFloorSliderDragged:m_floorSelection];

    [self refreshArrowState];
}

- (void) dragButton:(ImmediatePanGestureRecognizer*)recognizer
{
    if(recognizer.state == UIGestureRecognizerStateChanged ||
       recognizer.state == UIGestureRecognizerStateEnded)
    {
        CGPoint translation = [recognizer translationInView:self.pFloorChangeButton];
        CGRect buttonFrame = self.pFloorChangeButton.frame;
        buttonFrame.origin.y += translation.y;

        {
            float y = buttonFrame.origin.y;
            float minY = 0.f;
            float maxY = self.pFloorPanel.frame.size.height-buttonFrame.size.height;
            y = (y < minY) ? minY : y;
            y = (y > maxY) ? maxY : y;
            buttonFrame.origin.y = y;
        }

        self.pFloorChangeButton.frame = buttonFrame;

        [recognizer setTranslation:CGPointZero inView:self.pFloorChangeButton];

        m_scrollRect.size = self.pFloorListView.bounds.size;
    }

    if(recognizer.state == UIGestureRecognizerStateBegan)
    {
        if(!self.pTimer)
        {
            self.pTimer = [NSTimer timerWithTimeInterval:1.0/60.0
                                                  target:self
                                                selector:@selector(step)
                                                userInfo:nil
                                                 repeats:YES];
        }
        [[NSRunLoop mainRunLoop] addTimer:self.pTimer forMode:NSDefaultRunLoopMode];
        m_scrollRect.origin = self.pFloorListView.contentOffset;

        [self showFloorLabels];
    }

    m_draggingFloorButton = recognizer.state != UIGestureRecognizerStateEnded &&
                            recognizer.state != UIGestureRecognizerStateFailed &&
                            recognizer.state != UIGestureRecognizerStateCancelled;
    m_floorButtonParameter = 1.0f - (float)(self.pFloorChangeButton.frame.origin.y / (self.pFloorPanel.frame.size.height-self.pFloorChangeButton.frame.size.height));

    if(m_draggingFloorButton)
    {
        [self.pFloorChangeButton setSelected:YES];
        [m_delegate onFloorSliderPressed];
    }
    else
    {
        int floorCount = [m_tableViewFloorNames count] - 1;
        int floorIndex = (int)roundf(m_floorSelection*floorCount);
        
        [m_delegate onFloorSliderReleased:floorIndex];

        [self moveButtonToFloorIndex:floorIndex :YES];
        [self.pFloorChangeButton setSelected:NO];
        [self hideFloorLabels];

        [self.pTimer invalidate];
        self.pTimer = nil;
    }
}

- (void) hideFloorLabels
{
    [self setFloorListAlpha:0.5f];

    self.pFloorOnButtonLabel.textColor = [self textColorNormal];
}

- (void) showFloorLabels
{
    [self setFloorListAlpha:1.0f];

    self.pFloorOnButtonLabel.textColor = [self textColorHighlighted];
}

- (void) setFloorListAlpha :(CGFloat)alpha
{
    [self.layer removeAllAnimations];

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.25];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];

    self.pFloorListView.alpha = alpha;
    self.pFloorListArrowDown.alpha = alpha;
    self.pFloorListArrowUp.alpha = alpha;

    [UIView commitAnimations];
}

- (void) moveButtonToFloorIndex:(int)floorIndex :(BOOL)shouldAnimate
{
    int floorCount = [m_tableViewFloorNames count];
    int row = floorCount - 1 - floorIndex;
    NSIndexPath* ipath = [NSIndexPath indexPathForRow:row inSection:0];

    CGFloat topY = self.pFloorListView.frame.origin.y;
    CGFloat bottomY = topY+self.pFloorListView.frame.size.height;
    CGFloat newY = 0;

    CGFloat controlHalfHeightBounds = self.pFloorListView.bounds.size.height/2;
    CGFloat heightForFloorIndex = topY + ((floorCount-1)-floorIndex) * m_floorDivisionHeight;
    if(heightForFloorIndex < controlHalfHeightBounds)
    {
        // Stay within the top half of the control;
        newY = heightForFloorIndex - m_halfButtonHeight + m_halfDivisionHeight;

    }
    else if(heightForFloorIndex >= self.pFloorListView.contentSize.height-(controlHalfHeightBounds+m_halfDivisionHeight))
    {
        // Stay within the bottom half of the control;
        newY = bottomY - m_halfButtonHeight - (floorIndex+0.5f)*m_floorDivisionHeight;
    }
    else
    {
        // Stay in the center
        newY = topY + controlHalfHeightBounds - m_halfButtonHeight;
    }


    if(shouldAnimate)
    {
        [UIView animateWithDuration:0.25
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^(void){
                             CGRect buttonFrame = self.pFloorChangeButton.frame;
                             buttonFrame.origin.y = newY;
                             self.pFloorChangeButton.frame = buttonFrame;

                             [self.pFloorListView scrollToRowAtIndexPath:ipath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];

        }
                         completion:^(BOOL finished)
        {
                              [self refreshArrowState];
        }];
    }
    else
    {
        CGRect buttonFrame = self.pFloorChangeButton.frame;
        buttonFrame.origin.y = newY;
        self.pFloorChangeButton.frame = buttonFrame;

        [self.pFloorListView scrollToRowAtIndexPath:ipath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        [self refreshArrowState];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [m_tableViewFloorNames count];
}

static NSString *CellIdentifier = @"floorCell";

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    const float divisionWidth = 30;
    const float divisionLabelWidth = 35;
    const float divisionLabelSpacing = 5;

    int floorIndex = static_cast<int>(indexPath.row);
    int floorCount = [m_tableViewFloorNames count];

    InteriorsExplorerFloorItemView *cell = (InteriorsExplorerFloorItemView*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(cell == nil)
    {
        cell = [[InteriorsExplorerFloorItemView alloc] initWithParams:divisionLabelWidth
                                                                      :divisionLabelSpacing
                                                                      :divisionWidth
                                                                      :m_floorDivisionHeight
                                                                      :CellIdentifier];

        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        if ([cell respondsToSelector:@selector(layoutMargins)])
        {
            cell.layoutMargins = UIEdgeInsetsZero;
        }

        if ([cell respondsToSelector:@selector(separatorInset)])
        {
            [cell setSeparatorInset:UIEdgeInsetsZero];
        }
    }

    NSString* nameString = m_tableViewFloorNames[floorIndex];

    BOOL top = (floorIndex==0);
    BOOL bottom = (floorIndex==floorCount-1);

    [cell setFloor:nameString :top :bottom];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return m_floorDivisionHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return m_floorDivisionHeight;
}

@end
