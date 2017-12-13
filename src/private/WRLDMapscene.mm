#include "WRLDMapscene.h"
#include "WRLDMapscene+Private.h"
#include "WRLDMapsceneStartLocation.h"
#include "WRLDMapsceneDataSource.h"

@interface WRLDMapscene()

@end

@implementation WRLDMapscene
{
    NSString* m_name;
    NSString* m_shortLink;
    NSString* m_apiKey;
    WRLDMapsceneStartLocation* m_wrldMapsceneStartLocation;
    
    WRLDMapsceneDataSource* m_wrldMapsceneDataSource;
    WRLDMapsceneSearchMenuConfig* m_wrldMapsceneSearchMenuConfig;
    //:TODO: Add DataSources
    //:TODO: Add MapsceneSearchConfig
}

-(NSString*)getName
{
    return m_name;
}
-(NSString*)getShortLink
{
    return m_shortLink;
}
-(NSString*)getApiKey
{
    return m_apiKey;
}
-(WRLDMapsceneStartLocation*)getWRLDMapsceneStartLocation
{
    return m_wrldMapsceneStartLocation;
}
-(WRLDMapsceneDataSource *)getWRLDMapsceneDataSource
{
    return m_wrldMapsceneDataSource;
}
-(WRLDMapsceneSearchMenuConfig *)getWRLDMapsceneSearchMenuConfig
{
    return m_wrldMapsceneSearchMenuConfig;
}

-(void)setName:(NSString*)name
{
    m_name = name;
}
-(void)setShortLink:(NSString*)shortLink
{
m_shortLink=shortLink;
}
-(void)setApiKey:(NSString*)apiKey
{
    m_apiKey=apiKey;
}
-(void)setWRLDMapsceneStartLocation:(WRLDMapsceneStartLocation*)wrldMapsceneStartLocation
{
    m_wrldMapsceneStartLocation = wrldMapsceneStartLocation;
}

-(void)setWRLDMapsceneDataSource:(WRLDMapsceneDataSource *)wrldMapsceneDataSource
{
    m_wrldMapsceneDataSource = wrldMapsceneDataSource;
}

-(void)setWRLDMapsceneSearchMenuConfig:(WRLDMapsceneSearchMenuConfig *)wrldMapsceneSearchMenuConfig
{
    m_wrldMapsceneSearchMenuConfig = wrldMapsceneSearchMenuConfig;
}

@end
