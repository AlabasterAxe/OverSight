//
//  RulesWindowController.m
//  OverSight
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//


#import "Consts.h"
#import "RuleRow.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "../Shared/Logging.h"
#import "RulesWindowController.h"
#import "../Shared/XPCProtocol.h"

@interface RulesWindowController ()

@end

@implementation RulesWindowController

@synthesize items;

//automatically called when nib is loaded
// ->just center window
-(void)awakeFromNib
{
    //load whitelisted items
    self.items = [NSMutableArray arrayWithContentsOfFile:[[[@"~" stringByAppendingPathComponent:APP_SUPPORT_DIRECTORY] stringByExpandingTildeInPath] stringByAppendingPathComponent:FILE_WHITELIST]];
    
    //no white-listed items?
    // ->show overlay with msg
    if(0 == self.items.count)
    {
        //add
        [self addOverlay];
        
        //set message
        self.message.stringValue = @"currently no applications have been 'whitelisted'";
        
        //hide spinner
        self.spinner.hidden = YES;
    }
    
    return;
}


//table delegate
// ->return number of rows
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    //count
    return self.items.count;
}

//table delegate method
// ->return cell for row
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //cell
    NSTableCellView *tableCell = nil;
    
    //process name
    NSString* processName = nil;
    
    //process path
    NSString* processPath = nil;
    
    //process icon
    NSImage* processIcon = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //device type
    NSString* device = nil;
    
    //sanity check
    if(row >= self.items.count)
    {
        //bail
        goto bail;
    }
    
    //grab process path
    processPath = [[self.items objectAtIndex:row] objectForKey:EVENT_PROCESS_PATH];
    
    //try find an app bundle
    appBundle = findAppBundle(processPath);
    if(nil != appBundle)
    {
        //grab name from app's bundle
        processName = [appBundle infoDictionary][@"CFBundleName"];
    }
    
    //still nil?
    // ->just grab from path
    if(nil == processName)
    {
        //from path
        processName = [processPath lastPathComponent];
    }
    
    //grab icon
    processIcon = getIconForProcess(processPath);
    
    //set device type for audio
    if(SOURCE_AUDIO.intValue == [[[self.items objectAtIndex:row] objectForKey:EVENT_DEVICE] intValue])
    {
        //set
        device = @"mic";
    }
    //set device type for mic
    else if(SOURCE_VIDEO.intValue == [[[self.items objectAtIndex:row] objectForKey:EVENT_DEVICE] intValue])
    {
        //set
        device = @"camera";
    }
    
    //init table cell
    tableCell = [tableView makeViewWithIdentifier:@"itemCell" owner:self];
    if(nil == tableCell)
    {
        //bail
        goto bail;
    }
    
    //set icon
    tableCell.imageView.image = processIcon;
    
    //set (main) text
    // process name (device)
    tableCell.textField.stringValue = [NSString stringWithFormat:@"%@ (access: %@)", processName, device];
    
    //set sub text
    [[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:processPath];
    
    //set detailed text color to gray
    ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG]).textColor = [NSColor grayColor];
    
//bail
bail:
    
    // Return the result
    return tableCell;

}

//automatically invoked
// ->create custom (sub-classed) NSTableRowView
-(NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    //row view
    RuleRow* rowView = nil;
    
    //row ID
    static NSString* const kRowIdentifier = @"RowView";
    
    //try grab existing row view
    rowView = [tableView makeViewWithIdentifier:kRowIdentifier owner:self];
    
    //make new if needed
    if(nil == rowView)
    {
        //create new
        // ->size doesn't matter
        rowView = [[RuleRow alloc] initWithFrame:NSZeroRect];
        
        //set row ID
        rowView.identifier = kRowIdentifier;
    }
    
    return rowView;
}

//delete a whitelist item
// ->gotta invoke the login item, as it can do that via XPC
-(IBAction)deleteRule:(id)sender
{
    //index of selected row
    NSInteger selectedRow = 0;
    
    //item
    NSDictionary* item = nil;
    
    //rule
    NSString* processPath = nil;
    
    //device
    NSNumber* device = nil;
    
    //grab selected row
    selectedRow = [self.tableView rowForView:sender];
    
    //grab item
    item = self.items[selectedRow];
    
    //extract path
    processPath = item[EVENT_PROCESS_PATH];
    
    //extract device
    device = item[EVENT_DEVICE];
    
    //remove from items
    [self.items removeObject:item];
    
    //add/show overlay
    [self addOverlay];
    
    //restart login item in background
    // ->pass in process path/device so it can un-whitelist via XPC
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
       //restart
       [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:YES args:@[processPath, [device stringValue]]];
        
       //remove overlay
       // ->also refreshes window
       [self removeOverlay];
        
    });
    
    return;
}

//add overlay to main window
-(void)addOverlay
{
    //frame
    NSRect frame = {0};
    
    //pre-req
    [self.overlay setWantsLayer:YES];
    
    //get main window's frame
    frame = self.window.contentView.frame;
    
    //set origin to 0/0
    frame.origin = CGPointZero;
    
    //update overlay to take up entire window
    self.overlay.frame = frame;
    
    //set overlay's view color to white
    self.overlay.layer.backgroundColor = [NSColor whiteColor].CGColor;
    
    //make it semi-transparent
    self.overlay.alphaValue = 0.85;
    
    //animate it
    [self.spinner startAnimation:nil];
    
    //add to main window
    [self.window.contentView addSubview:self.overlay];
    
    //show
    self.overlay.hidden = NO;
    
    //disable resize button
    [[self.window standardWindowButton:NSWindowZoomButton] setEnabled:NO];
    
    //disable resizing
    [self.window setStyleMask:self.window.styleMask^NSResizableWindowMask];
    
    return;
}

//remove overlay from main window & reload table
-(void)removeOverlay
{
    //remove overlay view on main thread & reload
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //hide view
        self.overlay.hidden = YES;
        
        //remove
        [self.overlay removeFromSuperview];
        
        //reload table
        [self.tableView reloadData];
        
        //disable resize button
        [[self.window standardWindowButton:NSWindowZoomButton] setEnabled:NO];
        
        //disable resizing
        [self.window setStyleMask:self.window.styleMask^NSResizableWindowMask];
        
    });
    
    return;
}

@end
