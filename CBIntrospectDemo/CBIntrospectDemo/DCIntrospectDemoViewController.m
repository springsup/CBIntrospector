//
//  DCIntrospectDemoViewController.m
//  DCIntrospectDemo
//
//  Created by Domestic Cat on 29/04/11.
//  Copyright 2011 Domestic Cat Software. All rights reserved.
//

#import "DCIntrospectDemoViewController.h"
#import "CBIntrospect.h"
#import "CBMacros.h"

@implementation DCIntrospectDemoViewController
@synthesize activityIndicator;
@synthesize label;

- (void)dealloc
{
	[[CBIntrospect sharedIntrospector] removeNamesForViewsInView:self.view];

#if ! CB_HAS_ARC
    [activityIndicator release];
	[label release];
    [super dealloc];
#endif
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
	[super viewDidLoad];

	// set the activity indicator to a non-integer frame for demonstration
	self.activityIndicator.frame = CGRectOffset(self.activityIndicator.frame, 0.5, 0.0);
    
    // provide custom names for use by the View Introspector desktop app and console output
	[[CBIntrospect sharedIntrospector] setName:@"activityIndicator" forObject:self.activityIndicator accessedWithSelf:YES];
    [[CBIntrospect sharedIntrospector] setNameForViewController:self];
}

- (void)viewDidUnload
{
    [self setActivityIndicator:nil];
	[self setLabel:nil];

	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

#pragma mark Table View Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";

	UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        CB_NO_ARC([cell autorelease])
	}

	cell.textLabel.text = [NSString stringWithFormat:@"Row %i", indexPath.row];
	cell.detailTextLabel.text = @"Detailed Text";
	cell.accessoryType = UITableViewCellAccessoryCheckmark;

	return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 2;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [NSString stringWithFormat:@"Section %i", section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (IBAction)buttonTapped:(id)sender
{
}

- (IBAction)switchChanged:(id)sender
{
}

- (IBAction)sliderChanged:(id)sender
{
}

@end
