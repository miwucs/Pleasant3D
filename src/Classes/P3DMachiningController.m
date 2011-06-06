//
//  PrintController.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 18.02.10.
//  Copyright 2010 Pleasant Software. All rights reserved.
//

#import "P3DMachiningController.h"
#import <P3DCore/P3DCore.h>
#import "P3DDocumentController.h"
#import "P3DMachiningQueueManager.h"
#import "SliceNDiceDocument.h"

@implementation P3DMachiningController
@synthesize document;
@dynamic configuredMachines, selectedMachineIndex;

- (id) initWithMachinableDocument:(P3DMachinableDocument*)doc
{
	self = [super init];
	if (self != nil) {
		document = doc;
		
		if([document isKindOfClass:[SliceNDiceDocument class]])
		{
			selectedMachineUUID = [(SliceNDiceDocument*)document selectedMachineUUID];
		}
		else
			selectedMachineUUID = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultMachine"];
	}
	return self;
}

- (ConfiguredMachines*)configuredMachines
{
	return [ConfiguredMachines sharedInstance];
}

- (void)setSelectedMachineIndex:(NSInteger)value
{
	selectedMachineUUID = [[self.configuredMachines.configuredMachines objectAtIndex:value] objectForKey:@"uuid"];
	
	NSDictionary* currentMachineDesc = [[ConfiguredMachines sharedInstance] configuredMachineForUUID:selectedMachineUUID];
	P3DMachineDriverBase* currentMachineDriver = [currentMachineDesc objectForKey:@"driver"];
	if(contentView.subviews.count>0)
	{
		[[contentView.subviews objectAtIndex:0] removeFromSuperview];
	}
	
	NSView* driverPrintDialog = [currentMachineDriver printDialogView];
	if(driverPrintDialog)
	{
		NSRect sheetRect = [printSheet frame];
		sheetRect.size.width = NSWidth([driverPrintDialog frame]);
		sheetRect.size.height = NSHeight([driverPrintDialog frame])+NSHeight(sheetRect)-NSHeight([contentView frame]);
		[printSheet setFrame:sheetRect display:YES];
		[contentView addSubview:driverPrintDialog];
	}
}

- (NSInteger)selectedMachineIndex
{
	__block NSInteger selectedIndex = 0;
	[self.configuredMachines.configuredMachines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if([[obj objectForKey:@"uuid"] isEqualToString:selectedMachineUUID])
		{
			selectedIndex = idx;
			*stop=YES;
		}
	}];
	return selectedIndex;
}

- (void)showPrintDialog
{
	NSDictionary* currentMachineDesc = [[ConfiguredMachines sharedInstance] configuredMachineForUUID:selectedMachineUUID];
	P3DMachineDriverBase* currentMachineDriver = [currentMachineDesc objectForKey:@"driver"];
	if(currentMachineDriver && [NSBundle loadNibNamed:@"MachiningSheet" owner:self])
	{
		NSWindow* mainWindow = [document windowForSheet];
		
		NSView* driverPrintDialog = [currentMachineDriver printDialogView];
		if(driverPrintDialog)
		{
			NSRect sheetRect = [printSheet frame];
			sheetRect.size.width = NSWidth([driverPrintDialog frame]);
			sheetRect.size.height = NSHeight([driverPrintDialog frame])+NSHeight(sheetRect)-NSHeight([contentView frame]);
			[printSheet setFrame:sheetRect display:NO];
			[contentView addSubview:driverPrintDialog];
		}
		
		[NSApp beginSheet:printSheet modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}


- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
	[printSheet close];
	if(returnCode)
	{
		NSDictionary* currentMachineDesc = [[ConfiguredMachines sharedInstance] configuredMachineForUUID:selectedMachineUUID];
		P3DMachineDriverBase* currentMachineDriver = [currentMachineDesc objectForKey:@"driver"];
		P3DMachiningQueue* queue = [[P3DMachiningQueueManager sharedInstance] printingQueueForDriver:currentMachineDriver];
		[queue addMachiningJobForDocument:document withDriver:currentMachineDriver];
	}
}

- (IBAction)printPressed:(id)sender
{
	[NSApp endSheet:printSheet returnCode:YES];
}

- (IBAction)cancelPressed:(id)sender
{
	[NSApp endSheet:printSheet returnCode:NO];
}

@end
