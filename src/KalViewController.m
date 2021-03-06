/* 
 * Copyright (c) 2009 Keith Lazuka
 * License: http://www.opensource.org/licenses/mit-license.html
 */

#import "KalViewController.h"
#import "KalLogic.h"
#import "KalDataSource.h"
#import "KalDate.h"
#import "KalPrivate.h"

#import "MAEvent.h"

#define windowFrameForOrientation() (UIDeviceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])? [[UIApplication sharedApplication] keyWindow].frame:CGRectMake(0, 0,[[UIApplication sharedApplication] keyWindow].frame.size.height, [[UIApplication sharedApplication] keyWindow].frame.size.width))


#define PROFILER 0
#if PROFILER
#include <mach/mach_time.h>
#include <time.h>
#include <math.h>
void mach_absolute_difference(uint64_t end, uint64_t start, struct timespec *tp)
{
    uint64_t difference = end - start;
    static mach_timebase_info_data_t info = {0,0};

    if (info.denom == 0)
        mach_timebase_info(&info);
    
    uint64_t elapsednano = difference * (info.numer / info.denom);
    tp->tv_sec = elapsednano * 1e-9;
    tp->tv_nsec = elapsednano - (tp->tv_sec * 1e9);
}
#endif

NSString *const KalDataSourceChangedNotification = @"KalDataSourceChangedNotification";

@interface KalViewController ()
@property (nonatomic, retain, readwrite) NSDate *initialDate;
@property (nonatomic, retain, readwrite) NSDate *selectedDate;
- (KalView*)calendarView;
@end

@implementation KalViewController

@synthesize dataSource, delegate, initialDate, selectedDate;
@synthesize dayView;

- (id)initWithSelectedDate:(NSDate *)date
{
  if ((self = [super init])) {
    logic = [[KalLogic alloc] initForDate:date];
    self.initialDate = date;
    self.selectedDate = date;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(significantTimeChangeOccurred) name:UIApplicationSignificantTimeChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:KalDataSourceChangedNotification object:nil];
  }
  return self;
}

- (id)init
{
  return [self initWithSelectedDate:[NSDate date]];
}

- (KalView*)calendarView { return (KalView*)self.view; }

- (void)setDataSource:(id<KalDataSource>)aDataSource
{
  if (dataSource != aDataSource) {
    dataSource = aDataSource;
    tableView.dataSource = dataSource;
  }
}

- (void)setDelegate:(id<KalViewControllerDelegate>)aDelegate
{
  if (delegate != aDelegate) {
    delegate = aDelegate;
  }
}

- (void)clearTable
{
  [dataSource removeAllItems];
  [tableView reloadData];
}

- (void)reloadData
{
  [dataSource presentingDatesFrom:logic.fromDate to:logic.toDate delegate:self];
}

- (void)significantTimeChangeOccurred
{
  [[self calendarView] jumpToSelectedMonth];
  [self reloadData];
}

// -----------------------------------------
#pragma mark KalViewDelegate protocol

-(void) didTapPreviouslySelectedDate:(KalDate *)date withTile:(UIView*)tileView{
	[delegate rePressedOnDay:date.NSDate withView:tileView withController:self];
}

- (void)didSelectDate:(KalDate *)date
{
	self.selectedDate = [date NSDate];
	NSDate *from = [[date NSDate] cc_dateByMovingToBeginningOfDay];
	NSDate *to = [[date NSDate] cc_dateByMovingToEndOfDay];
	[self clearTable];
	[dataSource loadItemsFromDate:from toDate:to];
	[tableView reloadData];
	[tableView flashScrollIndicators];

	[dayView setDay:from];
	[dayView reloadData];
}

- (void)showPreviousMonth
{
  [self clearTable];
  [logic retreatToPreviousMonth];
  [[self calendarView] slideDown];
  [self reloadData];
}

- (void)showFollowingMonth
{
  [self clearTable];
  [logic advanceToFollowingMonth];
  [[self calendarView] slideUp];
  [self reloadData];
}

// -----------------------------------------
#pragma mark KalDataSourceCallbacks protocol

- (void)loadedDataSource:(id<KalDataSource>)theDataSource;
{
  NSArray *markedDates = [theDataSource markedDatesFrom:logic.fromDate to:logic.toDate];
  NSMutableArray *dates = [[markedDates mutableCopy] autorelease];
  for (int i=0; i<[dates count]; i++)
    [dates replaceObjectAtIndex:i withObject:[KalDate dateFromNSDate:[dates objectAtIndex:i]]];
  
  [[self calendarView] markTilesForDates:dates];
	KalDate * dateToShow	=	self.calendarView.selectedDate;
	if ([theDataSource respondsToSelector:@selector(dateOfLastModifiedEvent)] && [theDataSource didAutodisplayLastModifiedAlready] == FALSE){

		NSDate * recentDate	=	 [theDataSource dateOfLastModifiedEvent];
		if (recentDate != nil){
			dateToShow	=	[KalDate dateFromNSDate:recentDate];
			[self.calendarView selectDate:dateToShow];
			[theDataSource setDidAutodisplayLastModifiedAlready:TRUE];
		}
	}
  [self didSelectDate:dateToShow];
}

// ---------------------------------------
#pragma mark -

- (void)showAndSelectDate:(NSDate *)date
{
  if ([[self calendarView] isSliding])
    return;
  
  [logic moveToMonthForDate:date];
  
#if PROFILER
  uint64_t start, end;
  struct timespec tp;
  start = mach_absolute_time();
#endif
  
  [[self calendarView] jumpToSelectedMonth];
  
#if PROFILER
  end = mach_absolute_time();
  mach_absolute_difference(end, start, &tp);
  printf("[[self calendarView] jumpToSelectedMonth]: %.1f ms\n", tp.tv_nsec / 1e6);
#endif
  
  [[self calendarView] selectDate:[KalDate dateFromNSDate:date]];
  [self reloadData];
}

- (NSDate *)selectedDate
{
  return [self.calendarView.selectedDate NSDate];
}


// -----------------------------------------------------------------------------------
#pragma mark UIViewController

- (void)didReceiveMemoryWarning
{
  self.initialDate = self.selectedDate; // must be done before calling super
  [super didReceiveMemoryWarning];
}

- (void)loadView
{
	if (!self.title)
	self.title = @"Calendar";
	
	kalView = [[KalView alloc] initWithFrame:windowFrameForOrientation() delegate:self logic:logic] ;
	self.view = kalView;
	tableView = kalView.tableView;
	[tableView retain];
	
	dayView	=	[kalView.dayView retain];
	[dayView setDataSource:self];
	[dayView setDelegate:self];
	
	if (UIDeviceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]) || ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)){
		[kalView layoutForWideWidth];
	}else{
		[kalView layoutForNarrowWidth];		
	}

	
	[kalView selectDate:[KalDate dateFromNSDate:self.initialDate]];
	[self reloadData];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
  [tableView release];
  tableView = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [tableView flashScrollIndicators];
}

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
	
	return TRUE;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	if (UIDeviceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]) || ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)){
		[kalView layoutForWideWidth];
	}else{
		[kalView layoutForNarrowWidth];		
	}
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationSignificantTimeChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:KalDataSourceChangedNotification object:nil];
	[initialDate release];
	[selectedDate release];
	[logic release];
	[tableView release];
	[dayView release];
	[kalView release];
	[super dealloc];
}


#pragma mark - MADayView
- (NSArray *)dayView:(MADayView *)dayView eventsForDate:(NSDate *)date{
	NSDate *from = [date  cc_dateByMovingToBeginningOfDay];
	NSDate *to = [date  cc_dateByMovingToEndOfDay];
	NSArray * mkEvents	=	[dataSource eventsFrom:from to:to];
	
	NSMutableArray * maEvents	=	[NSMutableArray arrayWithCapacity:[mkEvents count]];
	for (EKEvent * event in mkEvents){
		MAEvent *nextMAEvent = [[MAEvent alloc] init];
		nextMAEvent.backgroundColor = [UIColor colorWithCGColor:[[event calendar] CGColor]];
		nextMAEvent.textColor = [UIColor whiteColor];
		nextMAEvent.allDay	=	event.isAllDay;
		nextMAEvent.start	=	event.startDate;
		nextMAEvent.end		=	event.endDate;
		nextMAEvent.title	=	event.title;
		nextMAEvent.userInfo	=	[NSDictionary dictionaryWithObject:event forKey:@"EKEvent"];
		[maEvents addObject:nextMAEvent];

		[nextMAEvent release];
		nextMAEvent	=	nil;
	}
	
	
	return maEvents;
}

- (void)dayView:(MADayView *)dayView eventTapped:(MAEvent *)event{
	if ([delegate respondsToSelector:@selector(tappedOnEvent:withController:)]){
		[delegate tappedOnEvent:[event.userInfo objectForKey:@"EKEvent"] withController:self];
	}
}

@end
