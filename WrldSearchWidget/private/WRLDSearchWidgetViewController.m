#import "WRLDSearchWidgetViewController.h"
#import "WRLDSearchBar.h"
#import "WRLDSearchProviderHandle.h"
#import "WRLDSuggestionProviderHandle.h"
#import "WRLDSearchWidgetTableViewController.h"
#import "WRLDSearchResultTableViewCell.h"
#import "WRLDSearchResultModel.h"
#import "WRLDSearchModel.h"
#import "WRLDSearchQueryObserver.h"
#import "WRLDSearchQuery.h"
#import "WRLDSearchResultSelectedObserver.h"
#import "WRLDSearchResultSelectedObserver+Private.h"
#import "WRLDMenuObserver.h"
#import "WRLDSearchWidgetStyle.h"
#import "WRLDSearchMenuModel.h"
#import "WRLDSearchMenuViewController.h"

@interface WRLDSearchWidgetViewController()
@property (unsafe_unretained, nonatomic) IBOutlet WRLDSearchBar *searchBar;

@property (weak, nonatomic) IBOutlet UIView *resultsTableContainerView;
@property (weak, nonatomic) IBOutlet UITableView *resultsTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *resultsTableHeightConstraint;

@property (weak, nonatomic) IBOutlet UIView *suggestionsTableContainerView;
@property (weak, nonatomic) IBOutlet UITableView *suggestionsTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *suggestionsTableHeightConstraint;

@property (weak, nonatomic) IBOutlet UIView* noResultsView;
@property (weak, nonatomic) IBOutlet UILabel* noResultsLabel;
@property (weak, nonatomic) IBOutlet id<WRLDViewVisibilityController> noResultsVisibilityController;

@property (weak, nonatomic) IBOutlet UIView *menuContainerView;
@property (weak, nonatomic) IBOutlet UIView *menuSeparator;
@property (weak, nonatomic) IBOutlet UILabel *menuTitleLabel;
@property (weak, nonatomic) IBOutlet UITableView *menuTableView;
@property (weak, nonatomic) IBOutlet UIView *menuTableFadeTop;
@property (weak, nonatomic) IBOutlet UIView *menuTableFadeBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *menuContainerViewHeightConstraint;

@end

@implementation WRLDSearchWidgetViewController
{
    WRLDSearchModel* m_searchModel;
    WRLDSearchMenuModel* m_menuModel;
    WRLDSearchWidgetTableViewController* m_searchResultsViewController;
    WRLDSearchWidgetTableViewController* m_suggestionsViewController;
    WRLDSearchMenuViewController* m_searchMenuViewController;
    NSString * m_suggestionsTableViewCellStyleIdentifier;
    NSString * m_searchResultsTableViewDefaultCellStyleIdentifier;
    
    WRLDSearchQuery * m_mostRecentQuery;
    
    NSInteger maxVisibleCollapsedResults;
    NSInteger maxVisibleExpandedResults;
    
    NSInteger maxVisibleSuggestions;
    
    UIColor * m_primaryBackgroundColor;
    UIColor * m_primaryForegroundColor;
    UIColor * m_focusBackgroundColor;
    UIColor * m_focusForegroundColor;
    UIColor * m_disabledBackgroundColor;
    UIColor * m_disabledForegroundColor;
    
    id<WRLDViewVisibilityController> m_activeResultsView;
    
    BOOL m_hasFocus;
    
    __weak QueryEvent m_searchQueryStartedEvent;
    __weak QueryEvent m_searchQueryCompletedEvent;
    __weak QueryEvent m_suggestionQueryCompletedEvent;
    
    NSMutableArray<WRLDSearchProviderHandle *>* m_searchProviders;
    NSMutableArray<WRLDSuggestionProviderHandle *>* m_suggestionProviders;
    
    BOOL m_viewDidLoad;
}

- (WRLDSearchResultSelectedObserver *)searchSelectionObserver
{
    return m_searchResultsViewController.selectionObserver;
}

- (WRLDSearchResultSelectedObserver *)suggestionSelectionObserver
{
    return m_suggestionsViewController.selectionObserver;
}

- (WRLDMenuObserver *)menuObserver
{
    return m_searchMenuViewController.observer;
}

- (instancetype)initWithSearchModel:(WRLDSearchModel *)searchModel
{
    return [self initWithSearchModel:searchModel
                           menuModel:nil];
}

- (instancetype)initWithSearchModel:(WRLDSearchModel *)searchModel
                          menuModel:(WRLDSearchMenuModel *)menuModel
{
    NSBundle* bundle = [NSBundle bundleForClass:[WRLDSearchWidgetViewController class]];
    self = [super initWithNibName: @"WRLDSearchWidget" bundle:bundle];
    if(self)
    {
        m_searchModel = searchModel;
        m_menuModel = menuModel;
        m_suggestionsTableViewCellStyleIdentifier = @"WRLDSuggestionTableViewCell";
        m_searchResultsTableViewDefaultCellStyleIdentifier = @"WRLDSearchResultTableViewCell";
        
        maxVisibleCollapsedResults = 3;
        maxVisibleExpandedResults = 100;
        
        maxVisibleSuggestions = 3;
        
        _style = [[WRLDSearchWidgetStyle alloc] init];
        
        m_hasFocus = NO;
        
        m_searchProviders = [[NSMutableArray<WRLDSearchProviderHandle *> alloc] init];
        m_suggestionProviders = [[NSMutableArray<WRLDSuggestionProviderHandle *>alloc ] init];
        
        m_viewDidLoad = NO;
    }
    return self;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    m_searchResultsViewController = [[WRLDSearchWidgetTableViewController alloc] initWithTableView: self.resultsTableView
                                                                                    visibilityView: self.resultsTableContainerView
                                                                                             style: self.style
                                                                                  heightConstraint:self.resultsTableHeightConstraint
                                                                             defaultCellIdentifier:m_searchResultsTableViewDefaultCellStyleIdentifier];
    
    m_suggestionsViewController = [[WRLDSearchWidgetTableViewController alloc] initWithTableView: self.suggestionsTableView
                                                                                  visibilityView: self.suggestionsTableContainerView
                                                                                           style: self.style
                                                                                heightConstraint:self.suggestionsTableHeightConstraint
                                                                           defaultCellIdentifier:m_suggestionsTableViewCellStyleIdentifier];

    m_searchMenuViewController = [[WRLDSearchMenuViewController alloc] initWithMenuModel:m_menuModel
                                                                          visibilityView:self.menuContainerView
                                                                              titleLabel:self.menuTitleLabel
                                                                           separatorView:self.menuSeparator
                                                                               tableView:self.menuTableView
                                                                        tableFadeTopView:self.menuTableFadeTop
                                                                     tableFadeBottomView:self.menuTableFadeBottom
                                                                        heightConstraint:self.menuContainerViewHeightConstraint
                                                                                   style:self.style];
    
    [m_suggestionsViewController.selectionObserver addResultSelectedEvent:^(id<WRLDSearchResultModel> selectedResultModel) {
        self.searchBar.text = selectedResultModel.title;
        [self triggerSearch : selectedResultModel.title];
    }];
    
    [self setupStyle];
    
    for(WRLDSearchProviderHandle * searchProviderHandle in m_searchProviders)
    {
        [self addFulfiller:searchProviderHandle toResultsViewController:m_searchResultsViewController];
    }
    for(WRLDSuggestionProviderHandle * suggestionProviderHandle in m_suggestionProviders)
    {
        [self addFulfiller:suggestionProviderHandle toResultsViewController:m_suggestionsViewController];
    }
    
    m_viewDidLoad = YES;
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self observeModel: m_searchModel];
}

-(void) viewWillDisappear:(BOOL)animated
{
    [self stopObservingModel: m_searchModel];
}
    
- (void) observeModel: (WRLDSearchModel *) model
{
    if(m_searchModel)
    {
        [self stopObservingModel: m_searchModel];
    }
    
    m_searchModel = model;
    
    QueryEvent searchQueryStartedEvent = ^(WRLDSearchQuery * query)
    {
        [m_searchResultsViewController showQuery: query];
        m_activeResultsView = m_searchResultsViewController;
        if(m_hasFocus)
        {
            [m_suggestionsViewController hide];
            [m_searchResultsViewController show];
        }
    };
    
    QueryEvent searchQueryCompletedEvent = ^(WRLDSearchQuery * query)
    {
        [m_searchResultsViewController showQuery: query];
        if(m_searchResultsViewController.visibleResults == 0)
        {
            m_activeResultsView = self.noResultsVisibilityController;
            if(m_hasFocus)
            {
                [m_searchResultsViewController hide];
                [self.noResultsVisibilityController show];
            }
        }
        else
        {
            m_activeResultsView = m_searchResultsViewController;
        }
    };
    
    QueryEvent suggestionQueryCompletedEvent = ^(WRLDSearchQuery * query)
    {
         [m_suggestionsViewController showQuery: query];
         [m_searchResultsViewController hide];
         if(m_hasFocus)
         {
             [m_suggestionsViewController show];
         }
         m_activeResultsView = m_suggestionsViewController;
    };
    
    // observers will hold strong references to block events to increase reference counter
    [m_searchModel.searchObserver addQueryStartingEvent: searchQueryStartedEvent];
    [m_searchModel.searchObserver addQueryCompletedEvent: searchQueryCompletedEvent];
    [m_searchModel.suggestionObserver addQueryCompletedEvent: suggestionQueryCompletedEvent];
    
    // self will weakly hold on to block event to remove from observer later and prevent circular references
    m_searchQueryStartedEvent = searchQueryStartedEvent;
    m_searchQueryCompletedEvent = searchQueryCompletedEvent;
    m_suggestionQueryCompletedEvent = suggestionQueryCompletedEvent;
}

- (void) stopObservingModel: (WRLDSearchModel *) model
{
    if(!model)
    {
        return;
    }
    
    if(m_searchQueryStartedEvent)
    {
        [model.searchObserver removeQueryStartingEvent: m_searchQueryStartedEvent];
    }
    
    if(m_searchQueryStartedEvent)
    {
        [model.searchObserver removeQueryCompletedEvent: m_searchQueryCompletedEvent];
    }
    
    if(m_searchQueryStartedEvent)
    {
        [model.suggestionObserver removeQueryCompletedEvent: m_suggestionQueryCompletedEvent];
    }
}

- (void) setupStyle
{
    [self.style call:^(UIColor *color) {
        self.resultsTableContainerView.backgroundColor = color;
    } toApply:WRLDSearchWidgetStylePrimaryColor];
    
    [self.style call:^(UIColor *color) {
        self.suggestionsTableContainerView.backgroundColor = color;
        self.noResultsView.backgroundColor = color;
    } toApply:WRLDSearchWidgetStyleSecondaryColor];
    
    [self.searchBar applyStyle: self.style];
    
    [self.style call:^(UIColor *color) {
        self.noResultsLabel.textColor = color;
    } toApply:WRLDSearchWidgetStyleWarningColor];
}

- (void) searchBarTextDidBeginEditing:(WRLDSearchBar *)searchBar
{
    [searchBar setActive: true];
    if(m_activeResultsView != nil)
    {
        [m_activeResultsView show];
    }
    m_hasFocus = YES;
}

- (void) searchBarTextDidEndEditing:(WRLDSearchBar *)searchBar
{
    [searchBar setActive: false];
}

- (void) resignFocus
{
    if(self.searchBar.isFirstResponder)
    {
        [self.searchBar resignFirstResponder];
    }
    
    if(m_activeResultsView != nil)
    {
        [m_activeResultsView hide];
    }
    m_hasFocus = NO;
}

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    NSString *trimmedSearchText = [searchText stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];

    if(m_mostRecentQuery && [trimmedSearchText isEqualToString: m_mostRecentQuery.queryString])
    {
        return;
    }
    
    [m_searchResultsViewController hide];
    [self.noResultsVisibilityController hide];
    
    [self cancelMostRecentQueryIfNotComplete];
    
    if([trimmedSearchText length] > 0)
    {
        m_mostRecentQuery = [m_searchModel getSuggestionsForString: trimmedSearchText];
    }
    else
    {
        [m_suggestionsViewController hide];
        m_activeResultsView = nil;
    }
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self triggerSearch: searchBar.text];
}

- (void) triggerSearch : (NSString *) queryString
{
    [self cancelMostRecentQueryIfNotComplete];
    [m_suggestionsViewController hide];
    m_mostRecentQuery = [m_searchModel getSearchResultsForString: queryString];
    [self.searchBar resignFirstResponder];
}

- (void) cancelMostRecentQueryIfNotComplete
{
    if(!m_mostRecentQuery.hasCompleted)
    {
        [m_mostRecentQuery cancel];
        m_mostRecentQuery = nil;
    }
}

- (void) displaySearchProvider :(WRLDSearchProviderHandle *) searchProvider
{
    [m_searchProviders addObject:searchProvider];
    if(m_viewDidLoad) {
        [self addFulfiller:searchProvider toResultsViewController:m_searchResultsViewController];
    }
}

- (void) addFulfiller:(id<WRLDSearchRequestFulfillerHandle>) fulfiller toResultsViewController:(WRLDSearchWidgetTableViewController*) tableViewController
{
    [tableViewController displayResultsFrom: fulfiller
                     maxToShowWhenCollapsed: maxVisibleCollapsedResults
                      maxToShowWhenExpanded: maxVisibleExpandedResults];
}

- (void) stopDisplayingSearchProvider :(WRLDSearchProviderHandle *) searchProvider
{
    [m_searchProviders removeObject:searchProvider];
    if(m_viewDidLoad) {
        [m_searchResultsViewController stopDisplayingResultsFrom: searchProvider];
    }
}

- (void) displaySuggestionProvider :(WRLDSuggestionProviderHandle *) suggestionProvider
{
    [m_suggestionProviders addObject:suggestionProvider];
    if(m_viewDidLoad) {
        [self addFulfiller:suggestionProvider toResultsViewController:m_suggestionsViewController];
    }
}

- (void) stopDisplayingSuggestionProvider :(WRLDSuggestionProviderHandle *) suggestionProvider
{
    [m_suggestionProviders removeObject:suggestionProvider];
    if(m_viewDidLoad) {
        [m_suggestionsViewController stopDisplayingResultsFrom: suggestionProvider];
    }
}

-(void) registerCellForResultsTable: (NSString *) cellIdentifier : (UINib *) nib
{
    [self.resultsTableView registerNib:nib forCellReuseIdentifier: cellIdentifier];
}

- (void)openMenu
{
    [self resignFocus];
    [m_searchMenuViewController open];
}

- (void)closeMenu
{
    [m_searchMenuViewController close];
}

- (void)collapseMenu
{
    [m_searchMenuViewController collapse];
}

- (void)expandMenuOptionAt:(NSUInteger)index
{
    [m_searchMenuViewController expandAt:index];
}

- (IBAction)menuButtonClicked:(id)menuButton
{
    [self resignFocus];
    [m_searchMenuViewController onMenuButtonClicked];
}

- (IBAction)menuBackButtonClicked:(id)backButton
{
    [m_searchMenuViewController onMenuBackButtonClicked];
}

@end

