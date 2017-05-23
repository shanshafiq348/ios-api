#import "Wrld.h"
#import "WRLDGestureDelegate.h"
#import "WRLDNativeMapView.h"
#import "WRLDMarker+Private.h"
#import "WRLDIndoorMap+Private.h"
#import "WRLDCoordinateWithAltitude.h"

#include "iOSApiRunner.h"
#include "iOSGlDisplayService.h"


#include "iOSApiHostModule.h"
#include "EegeoCameraApi.h"
#include "EegeoExpandFloorsApi.h"
#include "EegeoIndoorsApi.h"
#include "InteriorInteractionModel.h"
#include "EegeoApiHost.h"
#include "EegeoIndoorMapData.h"
#include "EegeoSpacesApi.h"

#include <string>

#import <QuartzCore/QuartzCore.h>

@interface WRLDMapView () <GLKViewDelegate>

@property (nonatomic) GLKView *glkView;
@property (nonatomic) EAGLContext *glContext;
@property (nonatomic) WRLDGestureDelegate* apiGestureDelegate;
@property (nonatomic) WRLDNativeMapView* nativeMapView;

@property (nonatomic) CADisplayLink* displayLink;

@property (nonatomic) CFTimeInterval prevDisplayLinkTimestamp;

@end


@implementation WRLDMapView
{
    Eegeo::ApiHost::iOS::iOSApiRunner* m_pApiRunner;


    CLLocationDegrees m_startLocationLatitude;
    CLLocationDegrees m_startLocationLongitude;
    bool m_startLocationLatitudeSet;
    bool m_startLocationLongitudeSet;

    std::map<int, WRLDMarker *> m_markersOnMap;
}


// todo make configurable? Was previously 2 in ios-api
const NSUInteger targetFrameInterval = 1;




- (instancetype)initWithCoder:(NSCoder*)coder
{
    if(self = [super initWithCoder:coder])
    {
        [self initView];
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if(self = [super initWithFrame:frame])
    {
        [self initView];
    }

    return self;
}


-(BOOL)isAppBackgrounded
{
    return [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
}


-(void)initView
{
    _glContext = nil;
    _displayLink = nil;
    _apiGestureDelegate = nil;
    _nativeMapView = nil;
    _glkView = nil;

    m_pApiRunner = NULL;

    m_startLocationLatitude = 0.0;
    m_startLocationLongitude = 0.0;
    m_startLocationLatitudeSet = false;
    m_startLocationLongitudeSet = false;

    m_markersOnMap = {};

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppWillTerminate)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationDidChange)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];


    if ([self isAppBackgrounded])
    {
        return;
    }


    // don't create if app is being launched into background - we need a GLES context, only get this when applicationDidBecomeActive
    [self createPlatform];

    Eegeo_ASSERT(m_pApiRunner != NULL);


    [self refreshDisplayLink];


    Eegeo::Api::EegeoCameraApi& cameraApi = [self getMapApi].GetCameraApi();

    const double latitude = 0.0;
    const double longitude = 0.0;
    const double interestAltitude = 0.0;
    const double distanceToInterest = 800000;
    const double heading = 0.0;
    const double pitch = 0.0;
    const double setPitch = false;

    cameraApi.InitialiseView(latitude, longitude, interestAltitude, distanceToInterest, heading, pitch, setPitch);

    Eegeo::ApiHost::IEegeoApiHost& apiHost = m_pApiRunner->GetEegeoApiHostModule()->GetEegeoApiHost();
    apiHost.OnStart();
}



-(void) createPlatform
{
    Eegeo_ASSERT(![self isAppBackgrounded]);

    [self createGLContextAndView];

    std::string apiKey = [[WRLDApi apiKey] UTF8String];

    NSBundle *frameworkBundle = [NSBundle bundleForClass:[self class]];
    std::string frameworkBundleId = [[frameworkBundle bundleIdentifier] UTF8String];

    m_pApiRunner = Eegeo::ApiHost::iOS::iOSApiRunner::Create(apiKey, frameworkBundleId, _glkView);

    const Eegeo::Rendering::ScreenProperties& screenProperties = m_pApiRunner->GetDisplayScreenProperties();

    _apiGestureDelegate = [[WRLDGestureDelegate alloc] initWith:&(m_pApiRunner->GetEegeoApiHostModule()->GetTouchController())
                                                                      :screenProperties.GetScreenWidth()
                                                                      :screenProperties.GetScreenHeight()
                                                                      :screenProperties.GetPixelScale()
                               ];

    [_apiGestureDelegate bind:self];

    _nativeMapView = Eegeo_NEW(WRLDNativeMapView)(self, *m_pApiRunner);
}


- (void)onAppWillEnterForeground
{
    if (m_pApiRunner == NULL)
    {
        return;
    }

    [self resume];
}

- (void)onAppDidBecomeActive
{
    if (m_pApiRunner == NULL)
    {
        [self createPlatform];
    }

    [self resume];
}

- (void)onAppDidEnterBackground
{
    if (m_pApiRunner == NULL)
    {
        return;
    }

    [self pause];
}

- (void)onAppWillTerminate
{

}

- (void)onDeviceOrientationDidChange
{
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    m_pApiRunner->NotifyViewFrameChanged();
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

- (void)dealloc
{
    [self commonTeardown];
    
}

- (void)commonTeardown
{
    [self refreshDisplayLink];

    [_glkView deleteDrawable];

    _glkView = nil;

    if ([EAGLContext currentContext] == _glContext)
    {
        [EAGLContext setCurrentContext:nil];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

    Eegeo_DELETE _nativeMapView;
    Eegeo_DELETE m_pApiRunner;
}

- (void)resume
{
    Eegeo_ASSERT(m_pApiRunner != NULL);

    if (!m_pApiRunner->IsPaused())
    {
        return;
    }

    if ([self isAppBackgrounded])
    {
        return;
    }

    _displayLink.paused = NO;


    m_pApiRunner->Resume();
}

- (void)pause
{
    Eegeo_ASSERT(m_pApiRunner != NULL);

    if (m_pApiRunner->IsPaused())
    {
        return;
    }

    _displayLink.paused = YES;

    [_glkView deleteDrawable];


    m_pApiRunner->Pause();
}


-(void) removeFromSuperview
{
    [super removeFromSuperview];
}

- (void)createGLContextAndView
{
    Eegeo_ASSERT(_glContext == nil);
    Eegeo_ASSERT(_glkView == nil);


    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    Eegeo_ASSERT(_glContext != nil, "Failed to create OpenGLES2 context");

    [EAGLContext setCurrentContext: _glContext];

    _glkView = [[GLKView alloc] initWithFrame:self.bounds context:_glContext];
    _glkView.delegate = self;
    _glkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _glkView.opaque = YES;

    [self addSubview:_glkView];
}


-(void)refreshDisplayLink
{
    bool doesExist = _displayLink != nil;
    bool shouldExist = self.window && self.superview;
    if (shouldExist == doesExist)
    {
        return;
    }
    else if (doesExist)
    {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    else
    {
        Eegeo_ASSERT(_displayLink == nil);
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateGlViewFromDisplayLink:)];
        _displayLink.frameInterval = targetFrameInterval;

        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        _prevDisplayLinkTimestamp = _displayLink.timestamp;
    }
}

- (void)didMoveToWindow
{
    [self refreshDisplayLink];
    [super didMoveToWindow];
}

- (void)didMoveToSuperview
{
    [self refreshDisplayLink];
    [super didMoveToSuperview];
}

- (void) updateGlViewFromDisplayLink:(CADisplayLink*)sender
{
    // mark GLKView as ready for draw on message from vsync-locked CADisplayLink
    [_glkView setNeedsDisplay];
}

- (void)glkView:(__unused GLKView *)view drawInRect:(__unused CGRect)rect
{
    Eegeo_ASSERT(m_pApiRunner != NULL);
    //CFTimeInterval timeNow = CFAbsoluteTimeGetCurrent();

    // _displayLink.timestamp is the time at which the previous frame was displayed
    const double maxFrameDelta = (4.0 * _displayLink.frameInterval) / 60.0;
    double displayLinkDelta = std::min(maxFrameDelta, (_displayLink.timestamp - _prevDisplayLinkTimestamp));

    _prevDisplayLinkTimestamp = _displayLink.timestamp;

    //Eegeo_TTY("displayLinkDelta %f, duration = %f", displayLinkDelta, _displayLink.duration);

    m_pApiRunner->Update(static_cast<float>(displayLinkDelta));
}


- (Eegeo::Api::EegeoMapApi&)getMapApi
{
    Eegeo::Api::EegeoMapApi& mapApi = m_pApiRunner->GetEegeoApiHostModule()->GetEegeoMapApi();
    return mapApi;
}

#pragma mark - public interface implementation -

- (CLLocationCoordinate2D)centerCoordinate
{
    Eegeo::Space::LatLong latLong = [self getMapApi].GetCameraApi().GetInterestLatLong();
    return CLLocationCoordinate2DMake(latLong.GetLatitudeInDegrees(), latLong.GetLongitudeInDegrees());
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate
{
    [self setCenterCoordinate:coordinate
                    zoomLevel:[self zoomLevel]
                    direction:[self direction]
                     animated:NO];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated
{
    [self setCenterCoordinate:coordinate
                    zoomLevel:[self zoomLevel]
                    direction:[self direction]
                     animated:animated];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate
                  zoomLevel:(double)zoomLevel
                   animated:(BOOL)animated
{
    [self setCenterCoordinate:coordinate
                    zoomLevel:zoomLevel
                    direction:[self direction]
                     animated:animated];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate
                  direction:(CLLocationDirection)direction
                   animated:(BOOL)animated
{
    [self setCenterCoordinate:coordinate
                    zoomLevel:[self zoomLevel]
                    direction:direction
                     animated:animated];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate
                  zoomLevel:(double)zoomLevel
                  direction:(CLLocationDirection)direction
                   animated:(BOOL)animated
{
    [self _setCenterCoordinate:coordinate
                     zoomLevel:zoomLevel
                     direction:direction
                      animated:animated];
}

- (double)zoomLevel
{
    return [self getMapApi].GetCameraApi().GetZoomLevel();
}

- (void)setZoomLevel:(double)zoomLevel
{
    [self setZoomLevel:zoomLevel animated:NO];
}

- (void)setZoomLevel:(double)zoomLevel animated:(BOOL)animated
{
    [self _setCenterCoordinate:[self centerCoordinate]
                     zoomLevel:zoomLevel
                     direction:[self direction]
                      animated:animated];
}

- (CLLocationDirection)direction
{
    return [self getMapApi].GetCameraApi().GetHeadingDegrees();
}

- (void)setDirection:(CLLocationDirection)direction
{
    [self setDirection:direction animated:NO];
}

- (void)setDirection:(CLLocationDirection)direction animated:(BOOL)animated
{
    [self _setCenterCoordinate:[self centerCoordinate]
                     zoomLevel:[self zoomLevel]
                     direction:direction
                      animated:animated];
}

- (void)_setCenterCoordinate:(CLLocationCoordinate2D)coordinate
                   zoomLevel:(double)zoomLevel
                   direction:(CLLocationDirection)direction
                    animated:(BOOL)animated
{
    Eegeo::Api::EegeoCameraApi& cameraApi = [self getMapApi].GetCameraApi();

    const double distance = cameraApi.GetDistanceFromZoomLevel(zoomLevel);

    [self _setView:coordinate distance:distance heading:direction pitch:-1 animated:animated];
}

- (void)setCoordinateBounds:(WRLDCoordinateBounds)bounds animated:(BOOL)animated
{
    Eegeo::Api::EegeoCameraApi& cameraApi = [self getMapApi].GetCameraApi();
    Eegeo::Space::LatLongAltitude northEast = Eegeo::Space::LatLongAltitude::FromDegrees(bounds.ne.latitude, bounds.ne.longitude, 0.0);
    Eegeo::Space::LatLongAltitude southWest = Eegeo::Space::LatLongAltitude::FromDegrees(bounds.sw.latitude, bounds.sw.longitude, 0.0);
    const bool allowInterruption = true;
    cameraApi.SetViewToBounds(northEast, southWest, animated, allowInterruption);
}

- (WRLDMapCamera *)camera
{
    Eegeo::Api::EegeoCameraApi& cameraApi = [self getMapApi].GetCameraApi();
    return [WRLDMapCamera cameraLookingAtCenterCoordinate:self.centerCoordinate fromDistance:cameraApi.GetDistanceToInterest() pitch:cameraApi.GetPitchDegrees() heading:self.direction];
}

- (void)setCamera:(WRLDMapCamera *)camera
{
    [self setCamera:camera animated:NO];
}

- (void)setCamera:(WRLDMapCamera *)camera animated:(BOOL)animated
{
    [self _setView:camera.centerCoordinate distance:camera.distance heading:camera.heading pitch:camera.pitch animated:animated];
}

- (void)setCamera:(WRLDMapCamera *)camera duration:(NSTimeInterval)duration
{
    [self _setView:camera.centerCoordinate distance:camera.distance heading:camera.heading pitch:camera.pitch duration:duration];
}

- (void)_setView:(CLLocationCoordinate2D)coordinate distance:(CLLocationDistance)distance heading:(double)heading pitch:(double)pitch animated:(BOOL)animated
{
    [self _setView:coordinate distance:distance heading:heading pitch:pitch duration:animated ? 10 : 0];
}

- (void)_setView:(CLLocationCoordinate2D)coordinate distance:(CLLocationDistance)distance heading:(double)heading pitch:(double)pitch duration:(NSTimeInterval)duration
{
    Eegeo::Api::EegeoCameraApi& cameraApi = [self getMapApi].GetCameraApi();

    const bool animated = duration > 0;
    const bool modifyPosition = true;
    const bool modifyDistance = true;
    const bool modifyHeading = true;
    const bool modifyPitch = pitch != -1;
    const bool hasTransitionDuration = animated;
    const bool jumpIfFarAway = true;
    const bool allowInterruption = true;

    const double altitude = 0.0;

    cameraApi.SetViewUsingZenithAngle(animated, coordinate.latitude, coordinate.longitude, altitude, modifyPosition, distance, modifyDistance, heading, modifyHeading, pitch, modifyPitch, duration, hasTransitionDuration, jumpIfFarAway, allowInterruption);
}

#pragma mark - markers -


- (void)addMarker:(WRLDMarker *)marker
{
    if ([marker isOnMapView]) return;
    [marker addToMapView:self];
    m_markersOnMap[[marker getId]] = marker;
}

- (void)addMarkers:(NSArray <WRLDMarker *> *)markers
{
    for (WRLDMarker* marker in markers)
    {
        [self addMarker:marker];
    }
}
- (void)removeMarker:(WRLDMarker *)marker
{
    if (![marker isOnMapView]) return;
    m_markersOnMap.erase([marker getId]);
    [marker removeFromMapView];
}

- (void)removeMarkers:(NSArray <WRLDMarker *> *)markers
{
    for (WRLDMarker* marker in markers)
    {
        [self removeMarker:marker];
    }
}

#pragma mark - controlling the indoor map view -

- (void)enterIndoorMap:(NSString*)indoorMapId
{
    const std::string interiorId = std::string([indoorMapId UTF8String]);
    [self getMapApi].GetIndoorsApi().EnterIndoorMap(interiorId);
}

- (void)exitIndoorMap
{
    [self getMapApi].GetIndoorsApi().ExitIndoorMap();
}

- (BOOL)isIndoors
{
    return [self getMapApi].GetIndoorsApi().HasActiveIndoorMap();
}

- (void) refreshActiveIndoorMap
{
    if ([self isIndoors])
    {
        const Eegeo::Api::EegeoIndoorMapData& indoorMapData = [self getMapApi].GetIndoorsApi().GetIndoorMapData();

        NSString* indoorMapId = [NSString stringWithCString:indoorMapData.indoorMapId.c_str() encoding:[NSString defaultCStringEncoding]];
        NSString* indoorMapName = [NSString stringWithCString:indoorMapData.indoorMapName.c_str() encoding:[NSString defaultCStringEncoding]];
        NSMutableArray<WRLDIndoorMapFloor*>* floors = [NSMutableArray array];
        for (int i=0; i<indoorMapData.floorCount; ++i)
        {
            const Eegeo::Api::EegeoIndoorMapFloorData& floorData = indoorMapData.floors[i];
            NSString* floorId = [NSString stringWithCString:floorData.floorId.c_str() encoding:[NSString defaultCStringEncoding]];
            NSString* floorName = [NSString stringWithCString:floorData.floorName.c_str() encoding:[NSString defaultCStringEncoding]];
            NSInteger floorIndex = static_cast<int>(floorData.floorNumber);

            WRLDIndoorMapFloor* floor = [[WRLDIndoorMapFloor alloc] initWithId:floorId name:floorName floorIndex:floorIndex];
            [floors addObject:floor];
        }
        NSString* userData = [NSString stringWithCString:indoorMapData.userData.c_str() encoding:[NSString defaultCStringEncoding]];

        WRLDIndoorMap* indoorMap = [[WRLDIndoorMap alloc] initWithId:indoorMapId name:indoorMapName floors:[floors copy] userData:userData];

        _activeIndoorMap = indoorMap;
    }
    else
    {
        _activeIndoorMap = nil;
    }
}

- (NSInteger)currentFloorIndex
{
    int currentFloor = [self isIndoors] ? [self getMapApi].GetIndoorsApi().GetSelectedFloorIndex() : -1;
    return static_cast<NSInteger>(currentFloor);
}

- (void)setFloorByIndex:(NSInteger)floorIndex
{
    [self getMapApi].GetIndoorsApi().SetSelectedFloorIndex(static_cast<int>(floorIndex));
}

- (void)setFloorInterpolation:(CGFloat)floorInterpolation
{
    Eegeo::Resources::Interiors::InteriorInteractionModel& interactionModel = [self getMapApi].GetExpandFloorsApi().GetInteriorInteractionModel();
    interactionModel.SetFloorParam(static_cast<float>(floorInterpolation));
}

- (void)moveUpFloors:(NSInteger)numberOfFloors
{
    NSInteger currentFloor = [self currentFloorIndex];
    if (currentFloor != -1)
    {
        [self setFloorByIndex:(currentFloor + numberOfFloors)];
    }
}

- (void)moveDownFloors:(NSInteger)numberOfFloors
{
    [self moveUpFloors:-numberOfFloors];
}

- (void)moveUpFloor
{
    [self moveUpFloors:1];
}

- (void)moveDownFloor
{
    [self moveDownFloors:1];
}

- (void)expandIndoorMapView
{
    Eegeo::Resources::Interiors::InteriorInteractionModel& interactionModel = [self getMapApi].GetExpandFloorsApi().GetInteriorInteractionModel();
    if (interactionModel.CanExpand())
    {
        interactionModel.ToggleExpanded();
    }
}

- (void)collapseIndoorMapView
{
    Eegeo::Resources::Interiors::InteriorInteractionModel& interactionModel = [self getMapApi].GetExpandFloorsApi().GetInteriorInteractionModel();
    if (!interactionModel.CanExpand())
    {
        interactionModel.ToggleExpanded();
    }
}

#pragma mark - WRLDMapView (Private)
    
    
- (void)notifyMapViewRegionWillChange
{
    if ([self.delegate respondsToSelector:@selector(mapViewRegionWillChange:)])
    {
        [self.delegate mapViewRegionWillChange:self];
    }
}
    
- (void)notifyMapViewRegionIsChanging
{
    if ([self.delegate respondsToSelector:@selector(mapViewRegionIsChanging:)])
    {
        [self.delegate mapViewRegionIsChanging:self];
    }
}

- (void)notifyMapViewRegionDidChange
{
    if ([self.delegate respondsToSelector:@selector(mapViewRegionDidChange:)])
    {
        [self.delegate mapViewRegionDidChange:self];
    }
}
    
-(void)notifyInitialStreamingCompleted
{
    if ([self.delegate respondsToSelector:@selector(mapViewDidFinishLoadingInitialMap:)])
    {
        [self.delegate mapViewDidFinishLoadingInitialMap:self];
    }
}

-(void)notifyTouchTapped:(CGPoint)point
{
    if ([self.delegate respondsToSelector:@selector(mapView:didTapMap:)])
    {
        Eegeo::Api::EegeoSpacesApi& spacesApi = [self getMapApi].GetSpacesApi();
        
        Eegeo::v2 p = Eegeo::v2(static_cast<float>(point.x), static_cast<float>(point.y));
        Eegeo::Space::LatLongAltitude lla(0.0, 0.0, 0.0);
        
        bool success = spacesApi.TryGetScreenToTerrainPoint(p, lla);
        
        if (success)
        {
            WRLDCoordinateWithAltitude coordinateWithAltitude = WRLDCoordinateWithAltitudeMake(CLLocationCoordinate2DMake(lla.GetLatitudeInDegrees(), lla.GetLongitudeInDegrees()), lla.GetAltitude());
            
            [self.delegate mapView:self didTapMap:coordinateWithAltitude];
        }
    }
}

- (void)notifyMarkerTapped:(int)markerId
{
    if (m_markersOnMap.count(markerId) == 0) return;
    if ([self.delegate respondsToSelector:@selector(mapView:didTapMarker:)])
    {
        [self.delegate mapView:self didTapMarker:m_markersOnMap.at(markerId)];
    }
}

- (void)notifyEnteredIndoorMap
{
    [self refreshActiveIndoorMap];
    if ([self.indoorMapDelegate respondsToSelector:@selector(didEnterIndoorMap)])
    {
        [self.indoorMapDelegate didEnterIndoorMap];
    }
}

- (void)notifyExitedIndoorMap
{
    [self refreshActiveIndoorMap];
    if ([self.indoorMapDelegate respondsToSelector:@selector(didExitIndoorMap)])
    {
        [self.indoorMapDelegate didExitIndoorMap];
    }
}

@end


#pragma mark - IBAdditions implementation -

@implementation WRLDMapView (IBAdditions)

- (double)latitude
{
    return self.centerCoordinate.latitude;
    
}

- (double)longitude
{
    return self.centerCoordinate.longitude;
}

- (void)setLatitude:(double)latitude
{
    m_startLocationLatitude = latitude;
    m_startLocationLatitudeSet = true;
    [self _trySetCenterCoordinateFromStartLocation];
}

- (void)setLongitude:(double)longitude
{
    m_startLocationLongitude = longitude;
    m_startLocationLongitudeSet = true;
    [self _trySetCenterCoordinateFromStartLocation];
}

- (void)_trySetCenterCoordinateFromStartLocation
{
    if (!m_startLocationLatitudeSet)
        return;
    if (!m_startLocationLongitudeSet)
        return;

    self.centerCoordinate = CLLocationCoordinate2DMake(m_startLocationLatitude, m_startLocationLongitude);
}

@end
