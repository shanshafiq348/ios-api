#import "WRLDMenuTableSectionViewModel.h"
#import "WRLDMenuGroup.h"
#import "WRLDMenuOption.h"

@implementation WRLDMenuTableSectionViewModel
{
    WRLDMenuOption* m_menuOption;
    NSString* m_displayText;
    
    bool m_isTitleSection;
    bool m_isFirstOptionInGroup;
    bool m_isLastOptionInGroup;
}

- (instancetype)initWithMenuGroup:(WRLDMenuGroup *)menuGroup
{
    self = [self init];
    
    m_isTitleSection = true;
    m_displayText = menuGroup.title;
    m_isFirstOptionInGroup = true;
    m_isLastOptionInGroup = ([[menuGroup getOptions] count] == 0);
    
    return self;
}

- (instancetype)initWithMenuGroup:(WRLDMenuGroup *)menuGroup
                      optionIndex:(NSUInteger)optionIndex
{
    self = [self init];
    
    NSUInteger optionCount = [[menuGroup getOptions] count];
    if (optionIndex < optionCount)
    {
        m_menuOption = [[menuGroup getOptions] objectAtIndex:optionIndex];
        m_displayText = m_menuOption.text;
        m_isFirstOptionInGroup = (optionIndex == 0) && ![menuGroup hasTitle];
        m_isLastOptionInGroup = (optionIndex == optionCount - 1);
    }
    
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _expandedState = Collapsed;
        m_displayText = nil;
        m_menuOption = nil;
        m_isTitleSection = false;
        m_isFirstOptionInGroup = false;
        m_isLastOptionInGroup = false;
    }
    return self;
}

- (bool)isTitleSection
{
    return m_isTitleSection;
}

- (bool)isFirstOptionInGroup
{
    return m_isFirstOptionInGroup;
}

- (bool)isLastOptionInGroup
{
    return m_isLastOptionInGroup;
}

- (bool)isExpandable
{
    return (!m_isTitleSection && [m_menuOption hasChildren]);
}

- (void)setExpandedState:(ExpandedStateType)state
{
    if ([self isExpandable])
    {
        _expandedState = state;
    }
}

- (NSString *)getText
{
    return m_displayText;
}

- (NSInteger)getChildCount
{
    if (m_menuOption != nil)
    {
        return [[m_menuOption getChildren] count];
    }
    return 0;
}

- (WRLDMenuChild *)getChildAtIndex:(NSUInteger)index
{
    if (m_menuOption != nil)
    {
        if (index < [[m_menuOption getChildren] count])
        {
            return [[m_menuOption getChildren] objectAtIndex:index];
        }
    }
    return nil;
}

@end

