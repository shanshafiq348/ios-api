#pragma once

#import <UIKit/UIKit.h>

@class WRLDSearchModel;
@class WRLDSearchMenuModel;
@class WRLDSearchProviderHandle;
@class WRLDSuggestionProviderHandle;
@class WRLDSearchResultSelectedObserver;
@class WRLDMenuObserver;
@class WRLDSearchWidgetStyle;

@interface WRLDSearchWidgetViewController : UIViewController <UISearchBarDelegate>

@property (nonatomic, readonly) WRLDSearchResultSelectedObserver * searchSelectionObserver;
@property (nonatomic, readonly) WRLDSearchResultSelectedObserver * suggestionSelectionObserver;
@property (nonatomic, readonly) WRLDMenuObserver * menuObserver;
@property (nonatomic, readonly) WRLDSearchWidgetStyle * style;
@property (nonatomic, readonly) BOOL isMenuOpen;
@property (nonatomic, readonly) BOOL isResultsViewVisible;

- (instancetype)initWithSearchModel:(WRLDSearchModel *)searchModel;

- (instancetype)initWithSearchModel:(WRLDSearchModel *)searchModel
                          menuModel:(WRLDSearchMenuModel *)menuModel;

-(void) displaySearchProvider :(WRLDSearchProviderHandle*) searchProvider;
-(void) displaySuggestionProvider :(WRLDSuggestionProviderHandle*) suggestionProvider;
-(void) registerNib: (UINib *) nib forUseWithResultsTableCellIdentifier: (NSString *) cellIdentifier;

- (void) clearSearch;

- (void) showResultsView;

- (void) hideResultsView;

- (void) resignFocus;

- (void)openMenu;

- (void)closeMenu;

- (void)collapseMenu;

- (void)expandMenuOptionAt:(NSUInteger)index;

@end