//
//  SettingsScrollView.m
//  Sammelbild
//
//  Created by Enie Weiß on 14.01.13.
//  Copyright (c) 2013 Enie Weiß. All rights reserved.
//

#import "SettingsScrollView.h"

@implementation SettingsScrollView

-(void)awakeFromNib
{
    [self setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"ui_settings_bg"]]];
    _bevelImage = [NSImage imageNamed:@"ui_bevel_right"];
}

-(BOOL)isOpaque
{
    return YES;
}

@end
