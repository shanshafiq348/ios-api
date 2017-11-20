#pragma once

#import <CoreLocation/CoreLocation.h>

typedef enum WRLDSearchResultType : NSUInteger {
    WRLDResult,
    WRLDSuggesgion
} WRLDSearchResultType;

@interface WRLDSearchResult : NSObject

//Key this to the provider....

@property (nonatomic) WRLDSearchResultType type;

@property (nonatomic, copy) NSString* title;

@property (nonatomic, copy) NSString* subTitle;

@property (nonatomic, copy) NSString* iconKey;

@property (nonatomic) CLLocationCoordinate2D latLng;

@end

