//
//  GrowlBezierPathAdditions.m
//  Display Plugins
//
//  Created by Ingmar Stein on 17.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlBezierPathAdditions.h"

@implementation NSBezierPath(GrowlBezierPathAdditions)
+ (NSBezierPath *) bezierPathWithRoundedRect:(NSRect)rect radius:(float)radius {
	NSRect irect = NSInsetRect( rect, radius, radius );
	float minX = NSMinX( irect );
	float minY = NSMinY( irect );
	float maxX = NSMaxX( irect );
	float maxY = NSMaxY( irect );

	NSBezierPath *path = [NSBezierPath bezierPath];

	[path appendBezierPathWithArcWithCenter:NSMakePoint( minX, minY )
									 radius:radius
								 startAngle:180.0f
								   endAngle:270.0f];

	[path appendBezierPathWithArcWithCenter:NSMakePoint( maxX, minY )
									 radius:radius
								 startAngle:270.0f
								   endAngle:360.0f];

	[path appendBezierPathWithArcWithCenter:NSMakePoint( maxX, maxY )
									 radius:radius
								 startAngle:0.0f
								   endAngle:90.0f];

	[path appendBezierPathWithArcWithCenter:NSMakePoint( minX, maxY )
									 radius:radius
								 startAngle:90.0f
								   endAngle:180.0f];

	[path closePath];

	return path;
}

@end
