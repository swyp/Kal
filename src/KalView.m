/* 
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import "KalView.h"
#import "KalGridView.h"
#import "KalLogic.h"
#import "KalPrivate.h"
#import <QuartzCore/QuartzCore.h>

@interface KalView ()
- (void)addSubviewsToHeaderView:(UIView *)headerView;
- (void)addSubviewsToContentView:(UIView *)contentView;
- (void)setHeaderTitleText:(NSString *)text;
@end

static const CGFloat kHeaderHeight = 44.f;
static const CGFloat kMonthLabelHeight = 17.f;

@implementation KalView

@synthesize delegate, tableView, dayView;

- (id)initWithFrame:(CGRect)frame delegate:(id<KalViewDelegate>)theDelegate logic:(KalLogic *)theLogic
{
  if ((self = [super initWithFrame:frame])) {
    delegate = theDelegate;
    logic = [theLogic retain];
    [logic addObserver:self forKeyPath:@"selectedMonthNameAndYear" options:NSKeyValueObservingOptionNew context:NULL];
    self.autoresizesSubviews = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
	  
	contentView = [[UIView alloc] initWithFrame:CGRectMake(0.f, kHeaderHeight, frame.size.width, frame.size.height - kHeaderHeight)] ;

	contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self addSubviewsToContentView:contentView];

    headerView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, frame.size.width, kHeaderHeight)] ;
    headerView.backgroundColor = [UIColor grayColor];
	  [headerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [self addSubviewsToHeaderView:headerView];
    [self addSubview:headerView];
    
    [self insertSubview:contentView belowSubview:headerView];
  }
  
  return self;
}

- (id)initWithFrame:(CGRect)frame
{
  [NSException raise:@"Incomplete initializer" format:@"KalView must be initialized with a delegate and a KalLogic. Use the initWithFrame:delegate:logic: method."];
  return nil;
}

- (void)redrawEntireMonth { [self jumpToSelectedMonth]; }

- (void)slideDown { [gridView slideDown]; }
- (void)slideUp { [gridView slideUp]; }

- (void)showPreviousMonth
{
  if (!gridView.transitioning)
    [delegate showPreviousMonth];
}

- (void)showFollowingMonth
{
  if (!gridView.transitioning)
    [delegate showFollowingMonth];
}

- (void)addSubviewsToHeaderView:(UIView *)hView
{
  const CGFloat kChangeMonthButtonWidth = 46.0f;
  const CGFloat kChangeMonthButtonHeight = 30.0f;
  const CGFloat kMonthLabelWidth = 200.0f;
  const CGFloat kHeaderVerticalAdjust = 3.f;
  
  // Header background gradient
  UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Kal.bundle/kal_grid_background.png"]];
  CGRect imageFrame = hView.frame;
  imageFrame.origin = CGPointZero;
  backgroundView.frame = imageFrame;
	[backgroundView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
  [hView addSubview:backgroundView];
  [backgroundView release];
  
  // Create the previous month button on the left side of the view
  CGRect previousMonthButtonFrame = CGRectMake(self.left,
                                               kHeaderVerticalAdjust,
                                               kChangeMonthButtonWidth,
                                               kChangeMonthButtonHeight);
  UIButton *previousMonthButton = [[UIButton alloc] initWithFrame:previousMonthButtonFrame];
  [previousMonthButton setImage:[UIImage imageNamed:@"Kal.bundle/kal_left_arrow.png"] forState:UIControlStateNormal];
  previousMonthButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  previousMonthButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  [previousMonthButton addTarget:self action:@selector(showPreviousMonth) forControlEvents:UIControlEventTouchUpInside];
  [hView addSubview:previousMonthButton];
  [previousMonthButton release];
  
  // Draw the selected month name centered and at the top of the view
  CGRect monthLabelFrame = CGRectMake((self.width/2.0f) - (kMonthLabelWidth/2.0f),
                                      kHeaderVerticalAdjust,
                                      kMonthLabelWidth,
                                      kMonthLabelHeight);
  headerTitleLabel = [[UILabel alloc] initWithFrame:monthLabelFrame];
  headerTitleLabel.backgroundColor = [UIColor clearColor];
  headerTitleLabel.font = [UIFont boldSystemFontOfSize:22.f];
  headerTitleLabel.textAlignment = UITextAlignmentCenter;
  headerTitleLabel.textColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Kal.bundle/kal_header_text_fill.png"]];
  headerTitleLabel.shadowColor = [UIColor whiteColor];
  headerTitleLabel.shadowOffset = CGSizeMake(0.f, 1.f);
	[headerTitleLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin];

  [self setHeaderTitleText:[logic selectedMonthNameAndYear]];
  [hView addSubview:headerTitleLabel];
  
  // Create the next month button on the right side of the view
  CGRect nextMonthButtonFrame = CGRectMake(self.width - kChangeMonthButtonWidth,
                                           kHeaderVerticalAdjust,
                                           kChangeMonthButtonWidth,
                                           kChangeMonthButtonHeight);
  UIButton *nextMonthButton = [[UIButton alloc] initWithFrame:nextMonthButtonFrame];
  [nextMonthButton setImage:[UIImage imageNamed:@"Kal.bundle/kal_right_arrow.png"] forState:UIControlStateNormal];
  nextMonthButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  nextMonthButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  [nextMonthButton addTarget:self action:@selector(showFollowingMonth) forControlEvents:UIControlEventTouchUpInside];
	[nextMonthButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin];

  [hView addSubview:nextMonthButton];
  [nextMonthButton release];
  
  // Add column labels for each weekday (adjusting based on the current locale's first weekday)
  NSArray *weekdayNames = [[[[NSDateFormatter alloc] init] autorelease] shortWeekdaySymbols];
  NSUInteger firstWeekday = [[NSCalendar currentCalendar] firstWeekday];
  NSUInteger i = firstWeekday - 1;
	NSUInteger maxDays = 7;
	NSInteger currentDay	=	firstWeekday;
  for (CGFloat xOffset = 0.f; xOffset < hView.width && currentDay< firstWeekday+maxDays ; xOffset += [KalGridView tileSize].width, i = (i+1)%7) {
    CGRect weekdayFrame = CGRectMake(xOffset, 30.f, [KalGridView tileSize].width, kHeaderHeight - 29.f);
    UILabel *weekdayLabel = [[UILabel alloc] initWithFrame:weekdayFrame];
    weekdayLabel.backgroundColor = [UIColor clearColor];
    weekdayLabel.font = [UIFont boldSystemFontOfSize:10.f];
    weekdayLabel.textAlignment = UITextAlignmentCenter;
    weekdayLabel.textColor = [UIColor colorWithRed:0.3f green:0.3f blue:0.3f alpha:1.f];
    weekdayLabel.shadowColor = [UIColor whiteColor];
    weekdayLabel.shadowOffset = CGSizeMake(0.f, 1.f);
    weekdayLabel.text = [weekdayNames objectAtIndex:i];
    [hView addSubview:weekdayLabel];
    [weekdayLabel release];
	  
	  currentDay++;
  }
}

- (void)addSubviewsToContentView:(UIView *)cView
{
  // Both the tile grid and the list of events will automatically lay themselves
  // out to fit the # of weeks in the currently displayed month.
  // So the only part of the frame that we need to specify is the width.
  CGRect fullWidthAutomaticLayoutFrame = CGRectMake(0.f, 0.f, self.width, 0.f);

  // The tile grid (the calendar body)
  gridView = [[KalGridView alloc] initWithFrame:self.frame logic:logic delegate:delegate];
  [gridView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:NULL];
	[gridView setAutoresizingMask:UIViewAutoresizingNone];
  [cView addSubview:gridView];

  // The list of events for the selected day
//  tableView = [[UITableView alloc] initWithFrame:fullWidthAutomaticLayoutFrame style:UITableViewStylePlain];
//  tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//  [contentView addSubview:tableView];

	
	CGRect	dayViewFrame	=	CGRectMake(0,gridView.frame.size.height + kHeaderHeight, cView.width, cView.height - (gridView.frame.size.height + kHeaderHeight));
	dayView	=	[[MADayView alloc] init];
	dayView.autoScrollToFirstEvent	= YES;
	dayView.layer.borderWidth		= 2;
	dayView.layer.borderColor		= [[UIColor lightGrayColor] CGColor];
	dayView.autoresizingMask		= UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
	[dayView setFrame:dayViewFrame];
	[cView addSubview:dayView];
	[cView sendSubviewToBack:dayView];
	
  // Drop shadow below tile grid and over the list of events for the selected day
  shadowView = [[UIImageView alloc] initWithFrame:fullWidthAutomaticLayoutFrame];
	[shadowView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
  shadowView.image = [UIImage imageNamed:@"Kal.bundle/kal_grid_shadow.png"];
  shadowView.height = shadowView.image.size.height;
  [cView addSubview:shadowView];
  
  // Trigger the initial KVO update to finish the contentView layout
  [gridView sizeToFit];
}

-(void) layoutForWideWidth{
	CGRect	dayViewFrame	=	CGRectMake(gridView.frame.size.width,0, contentView.width - gridView.frame.size.width, gridView.frame.size.height);
	if (CGRectEqualToRect(dayViewFrame , dayView.frame) == NO){
		[dayView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleLeftMargin];
		[dayView setAlpha:0];
		[dayView setFrame:dayViewFrame];
		[UIView animateWithDuration:.3 animations:^{
			[dayView setAlpha:1];
		}];
	}

}
-(void) layoutForNarrowWidth{
	CGRect	dayViewFrame	=	CGRectMake(0,gridView.frame.size.height, contentView.width, contentView.height - (gridView.frame.size.height + kHeaderHeight));
	if (CGRectEqualToRect(dayViewFrame , dayView.frame) == NO){
		[dayView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin];
		[dayView setAlpha:0];
		[dayView setFrame:dayViewFrame];
		[UIView animateWithDuration:.3 animations:^{
			[dayView setAlpha:1];
		}];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (object == gridView && [keyPath isEqualToString:@"frame"]) {
    
    /* Animate tableView filling the remaining space after the
     * gridView expanded or contracted to fit the # of weeks
     * for the month that is being displayed.
     *
     * This observer method will be called when gridView's height
     * changes, which we know to occur inside a Core Animation
     * transaction. Hence, when I set the "frame" property on
     * tableView here, I do not need to wrap it in a
     * [UIView beginAnimations:context:].
     */
    CGFloat gridBottom = gridView.top + gridView.height;
    CGRect frame = dayView.frame;
    frame.origin.y = gridBottom;
    frame.size.height = contentView.height - gridBottom;
//    dayView.frame = frame;
    shadowView.top = gridBottom;
    
  } else if ([keyPath isEqualToString:@"selectedMonthNameAndYear"]) {
    [self setHeaderTitleText:[change objectForKey:NSKeyValueChangeNewKey]];
    
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)setHeaderTitleText:(NSString *)text
{
  [headerTitleLabel setText:text];
  [headerTitleLabel sizeToFit];
  headerTitleLabel.left = floorf(self.width/2.f - headerTitleLabel.width/2.f);
}

- (void)jumpToSelectedMonth { [gridView jumpToSelectedMonth]; }

- (void)selectDate:(KalDate *)date { [gridView selectDate:date]; }

- (BOOL)isSliding { return gridView.transitioning; }

- (void)markTilesForDates:(NSArray *)dates { [gridView markTilesForDates:dates]; }

- (KalDate *)selectedDate { return gridView.selectedDate; }

- (void)dealloc
{
  [logic removeObserver:self forKeyPath:@"selectedMonthNameAndYear"];
  [logic release];
  
	[headerTitleLabel release];
	[gridView removeObserver:self forKeyPath:@"frame"];
	[gridView release];
	[tableView release];
	[shadowView release];
	[dayView release];
	dayView	=	nil;
	[contentView release];
	[headerView release];
	[super dealloc];
}

@end
