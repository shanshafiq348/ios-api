#import "WRLDMenuGroup.h"
#import "WRLDMenuGroup+Private.h"
#import "WRLDMenuOption.h"
#import "WRLDMenuOption+Private.h"
#import "WRLDMenuChangedListener.h"

@implementation WRLDMenuGroup
{
    NSMutableArray* m_options;
    id<WRLDMenuChangedListener> m_listener;
}

- (instancetype)init
{
    return [self initWithTitle:nil];
}

- (instancetype)initWithTitle:(nullable NSString *)title
{
    self = [super init];
    if (self)
    {
        _title = title;
        m_options = [[NSMutableArray alloc] init];
        m_listener = nil;
    }
    
    return self;
}

- (void)setTitle:(nullable NSString *)title
{
    _title = title;
    if (m_listener != nil)
    {
        [m_listener onMenuChanged];
    }
}

- (void)addOption:(WRLDMenuOption *)option
{
    [option setListener:m_listener];
    [m_options addObject:option];
    if (m_listener != nil)
    {
        [m_listener onMenuChanged];
    }
}

- (void)addOption:(NSString *)text
          context:(nullable NSObject *)context
{
    [self addOption:[[WRLDMenuOption alloc] initWithText:text
                                                 context:context]];
}

- (void)removeOption:(WRLDMenuOption *)option
{
    if ([m_options containsObject:option])
    {
        [option setListener:nil];
        [m_options removeObject:option];
        if (m_listener != nil)
        {
            [m_listener onMenuChanged];
        }
    }
}

- (void)insertOption:(WRLDMenuOption *)option
             atIndex:(NSUInteger)index
{
    if ([m_options count] > index)
    {
        [option setListener:m_listener];
        [m_options insertObject:option
                        atIndex:index];
        if (m_listener != nil)
        {
            [m_listener onMenuChanged];
        }
    }
}

- (void)removeOptionAtIndex:(NSUInteger)index
{
    if ([m_options count] > index)
    {
        [[m_options objectAtIndex:index] setListener:nil];
        [m_options removeObjectAtIndex:index];
        if (m_listener != nil)
        {
            [m_listener onMenuChanged];
        }
    }
}

- (void)removeAllOptions
{
    for (WRLDMenuOption* option in m_options)
    {
        [option setListener:nil];
    }
    
    [m_options removeAllObjects];
    if (m_listener != nil)
    {
        [m_listener onMenuChanged];
    }
}

#pragma mark - WRLDMenuGroup (Private)

- (NSMutableArray *)getOptions
{
    return m_options;
}

- (bool)hasTitle
{
    return _title != nil;
}

- (void)setListener:(id<WRLDMenuChangedListener>)listener
{
    m_listener = listener;
    for (WRLDMenuOption* option in m_options)
    {
        [option setListener:m_listener];
    }
}

@end


