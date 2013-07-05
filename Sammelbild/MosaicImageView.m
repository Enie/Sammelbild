//
//  MosaicImageView.m
//  Sammelbild
//
//  Created by Enie Weiß on 23.11.12.
//  Copyright (c) 2012 Enie Weiß. All rights reserved.
//

#import "MosaicImageView.h"

@implementation MosaicImageView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    [[NSColor darkGrayColor] set];
    NSRectFill(dirtyRect);
    
    [super drawRect:dirtyRect];
}

@end
