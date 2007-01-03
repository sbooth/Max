//
//  GrowlBezelWindowView.m
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 09/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "GrowlBezelWindowView.h"
#import "GrowlBezelPrefs.h"
#import "GrowlImageAdditions.h"
#import "GrowlBezierPathAdditions.h"

#define BORDER_RADIUS 20.0f

@implementation GrowlBezelWindowView

- (id) initWithFrame:(NSRect) frame {
	if ((self = [super initWithFrame:frame])) {
		layoutManager = [[NSLayoutManager alloc] init];
	}
	return self;
}

- (void)dealloc {
	[icon            release];
	[title           release];
	[text            release];
	[textColor       release];
	[backgroundColor release];
	[layoutManager   release];

	[super dealloc];
}

static void CharcoalShadeInterpolate( void *info, const float *inData, float *outData ) {
//	const float colors[2] = {0.15f, 0.35f};
	const float colors[2] = {27.0f / 255.0f * 1.5f, 58.0f / 255.0f};

	float a = inData[0] * 2.0f;
	float a_coeff;
	float c;

	if (a > 1.0f) {
		a = 2.0f - a;
	}
	a_coeff = 1.0f - a;
	c = a * colors[1] + a_coeff * colors[0];
	outData[0] = c;
	outData[1] = c;
	outData[2] = c;
	outData[3] = *(float *)info;
}

static void GlassShadeInterpolate( void *info, const float *inData, float *outData ) {
#pragma unused(inData)
	outData[0] = 1.0f;
	outData[1] = 1.0f;
	outData[2] = 1.0f;
	outData[3] = *(float *)info;
}

static void GlassShineInterpolate( void *info, const float *inData, float *outData ) {
#pragma unused(info)
	outData[0] = 1.0f;
	outData[1] = 1.0f;
	outData[2] = 1.0f;
	outData[3] = inData[0] * 0.25f;
}

- (void) drawRect:(NSRect)rect {
#pragma unused(rect)
	NSRect bounds = [self bounds];

	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds radius:BORDER_RADIUS];

	float opacityPref = BEZEL_OPACITY_DEFAULT;
	READ_GROWL_PREF_FLOAT(BEZEL_OPACITY_PREF, BezelPrefDomain, &opacityPref);
	float alpha = opacityPref * 0.01f;

	int style = 0;
	READ_GROWL_PREF_INT(BEZEL_STYLE_PREF, BezelPrefDomain, &style);
	NSGraphicsContext *graphicsContext;
	switch (style) {
		default:
		case 0:
			// default style
			[[backgroundColor colorWithAlphaComponent:alpha] set];
			[path fill];
			break;
		case 1:
			// charcoal
			graphicsContext = [NSGraphicsContext currentContext];
			[graphicsContext saveGraphicsState];

			[path setClip];
			struct CGFunctionCallbacks callbacks = { 0U, CharcoalShadeInterpolate, NULL };
			CGFunctionRef function = CGFunctionCreate( &alpha,
													   1U,
													   /*domain*/ NULL,
													   4U,
													   /*range*/ NULL,
													   &callbacks );
			CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
			CGPoint src, dst;
			src.x = NSMinX( bounds );
			src.y = NSMinY( bounds );
			dst.x = NSMaxX( bounds );
			dst.y = src.y;
			CGShadingRef shading = CGShadingCreateAxial( cspace, src, dst,
														 function, false, false );

			CGContextDrawShading( [graphicsContext graphicsPort], shading );

			CGShadingRelease( shading );
			CGColorSpaceRelease( cspace );
			CGFunctionRelease( function );

			[graphicsContext restoreGraphicsState];
			break;
		case 2:
			// glass
			[[NSColor colorWithCalibratedRed:1.0f green:1.0f blue:1.0f alpha:0.03f] set];
			[path fill];
			graphicsContext = [NSGraphicsContext currentContext];
			[graphicsContext saveGraphicsState];
			[path setClip];
			struct CGFunctionCallbacks glass_callbacks = { 0U, GlassShadeInterpolate, NULL };
			function = CGFunctionCreate( &alpha,
										 1U,
										 /*domain*/ NULL,
										 4U,
										 /*range*/ NULL,
										 &glass_callbacks );
			cspace = CGColorSpaceCreateDeviceRGB();
			src.x = bounds.origin.x + bounds.size.width * 0.75f;
			src.y = NSMinY( bounds ) - 80.0f;
			shading = CGShadingCreateRadial( cspace, src, 200.0f,
											 src, 400.0f, function,
											 false, false );

			CGContextDrawShading( [graphicsContext graphicsPort], shading );

			CGShadingRelease( shading );
			CGFunctionRelease( function );

			struct CGFunctionCallbacks shine_callbacks = { 0U, GlassShineInterpolate, NULL };
			function = CGFunctionCreate( /*info*/ NULL,
										 1U,
										 /*domain*/ NULL,
										 4U,
										 /*range*/ NULL,
										 &shine_callbacks );
			src.x = NSMidX( bounds );
			src.y = NSMidY( bounds );
			shading = CGShadingCreateRadial( cspace, src, 100.0f,
											 src, 0.0f, function,
											 false, false );

			CGContextDrawShading( [graphicsContext graphicsPort], shading );

			CGColorSpaceRelease( cspace );
			CGShadingRelease( shading );
			CGFunctionRelease( function );
			[graphicsContext restoreGraphicsState];
			[[NSColor colorWithCalibratedRed:1.0f green:1.0f blue:1.0f alpha:0.75f] set];
			[path stroke];
			break;
	}

	int sizePref = BEZEL_SIZE_NORMAL;
	READ_GROWL_PREF_INT(BEZEL_SIZE_PREF, BezelPrefDomain, &sizePref);

	// rects
	NSRect titleRect, textRect;
	NSPoint iconPoint;
	int maxRows;
	NSSize maxIconSize;
	if (sizePref == BEZEL_SIZE_NORMAL) {
		titleRect.origin.x = 12.0f;
		titleRect.origin.y = 90.0f;
		titleRect.size.width = 187.0f;
		titleRect.size.height = 30.0f;
		textRect.origin.x = 12.0f;
		textRect.origin.y = 4.0f;
		textRect.size.width = 187.0f;
		textRect.size.height = 80.0f;
		maxRows = 4;
		maxIconSize.width = 72.0f;
		maxIconSize.height = 72.0f;
		iconPoint.x = 70.0f;
		iconPoint.y = 120.0f;
	} else {
		titleRect.origin.x = 8.0f;
		titleRect.origin.y = 52.0f;
		titleRect.size.width = 143.0f;
		titleRect.size.height = 24.0f;
		textRect.origin.x = 8.0f;
		textRect.origin.y = 4.0f;
		textRect.size.width = 143.0f;
		textRect.size.height = 49.0f;
		maxRows = 2;
		maxIconSize.width = 48.0f;
		maxIconSize.height = 48.0f;
		iconPoint.x = 57.0f;
		iconPoint.y = 83.0f;
	}

	NSShadow *textShadow = [[NSShadow alloc] init];
	NSSize shadowSize = {0.0f, -2.0f};
	[textShadow setShadowOffset:shadowSize];
	[textShadow setShadowBlurRadius:3.0f];
	[textShadow setShadowColor:[NSColor blackColor]];

	// Draw the title, resize if text too big
	float titleFontSize = 20.0f;
	NSMutableParagraphStyle *parrafo = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[parrafo setAlignment:NSCenterTextAlignment];
	NSMutableDictionary *titleAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		textColor,                                   NSForegroundColorAttributeName,
		parrafo,                                     NSParagraphStyleAttributeName,
		[NSFont boldSystemFontOfSize:titleFontSize], NSFontAttributeName,
		textShadow,                                  NSShadowAttributeName,
		nil];
	float accumulator = 0.0f;
	BOOL minFontSize = NO;
	NSSize titleSize = [title sizeWithAttributes:titleAttributes];

	while (titleSize.width > (NSWidth(titleRect) - (titleSize.height * 0.5f))) {
		minFontSize = ( titleFontSize < 12.9f );
		if (minFontSize) {
			break;
		}
		titleFontSize -= 1.9f;
		accumulator += 0.5f;
		[titleAttributes setObject:[NSFont boldSystemFontOfSize:titleFontSize] forKey:NSFontAttributeName];
		titleSize = [title sizeWithAttributes:titleAttributes];
	}

	titleRect.origin.y += ceilf(accumulator);
	titleRect.size.height = titleSize.height;

	if (minFontSize) {
		[parrafo setLineBreakMode:NSLineBreakByTruncatingTail];
	}
	[title drawInRect:titleRect withAttributes:titleAttributes];
	[titleAttributes release];

	NSFont *textFont = [NSFont systemFontOfSize:14.0f];
	NSMutableDictionary *textAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		textColor,  NSForegroundColorAttributeName,
		parrafo,    NSParagraphStyleAttributeName,
		textFont,   NSFontAttributeName,
		textShadow, NSShadowAttributeName,
		nil];
	[textShadow release];
	[parrafo release];

	float height = [self descriptionHeight:text attributes:textAttributes width:textRect.size.width];
	float lineHeight = [layoutManager defaultLineHeightForFont:textFont];
	int rowCount = height / lineHeight;

	if (rowCount > maxRows) {
		[textAttributes setObject:[NSFont systemFontOfSize:12.0f] forKey:NSFontAttributeName];
	}
	[text drawInRect:textRect withAttributes:textAttributes];
	[textAttributes release];

	NSRect iconRect;
	iconRect.origin = iconPoint;
	iconRect.size = maxIconSize;
	[icon setFlipped:NO];
	[icon drawScaledInRect:iconRect operation:NSCompositeSourceOver fraction:1.0f];
}

- (void) setIcon:(NSImage *)anIcon {
	[icon release];
	icon = [anIcon retain];
	[self setNeedsDisplay:YES];
}

- (void) setTitle:(NSString *)aTitle {
	[title release];
	title = [aTitle copy];
	[self setNeedsDisplay:YES];
}

- (void) setText:(NSString *)aText {
	[text release];
	text = [aText copy];
	[self setNeedsDisplay:YES];
}

- (void) setPriority:(int)priority {
	NSString *key;
	NSString *textKey;
	switch (priority) {
		case -2:
			key = GrowlBezelVeryLowBackgroundColor;
			textKey = GrowlBezelVeryLowTextColor;
			break;
		case -1:
			key = GrowlBezelModerateBackgroundColor;
			textKey = GrowlBezelModerateTextColor;
			break;
		case 1:
			key = GrowlBezelHighBackgroundColor;
			textKey = GrowlBezelHighTextColor;
			break;
		case 2:
			key = GrowlBezelEmergencyBackgroundColor;
			textKey = GrowlBezelEmergencyTextColor;
			break;
		case 0:
		default:
			key = GrowlBezelNormalBackgroundColor;
			textKey = GrowlBezelNormalTextColor;
			break;
	}

	[backgroundColor release];

	Class NSDataClass = [NSData class];
	NSData *data = nil;

	READ_GROWL_PREF_VALUE(key, BezelPrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:NSDataClass]) {
		backgroundColor = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		backgroundColor = [NSColor blackColor];
	}
	[backgroundColor retain];
	[data release];
	data = nil;

	[textColor release];
	READ_GROWL_PREF_VALUE(textKey, BezelPrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:NSDataClass]) {
		textColor = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		textColor = [NSColor whiteColor];
	}
	[textColor retain];
	[data release];
}

- (float) descriptionHeight:(NSString *)theText attributes:(NSDictionary *)attributes width:(float)width {
	NSSize containerSize;
	containerSize.width = width;
	containerSize.height = FLT_MAX;
	NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:theText attributes:attributes];
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:containerSize];
	[textContainer setLineFragmentPadding:0.0f];

	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[layoutManager glyphRangeForTextContainer:textContainer];	// force layout

	float textHeight = [layoutManager usedRectForTextContainer:textContainer].size.height;
	[textContainer release];
	[textStorage release];

	return MAX (textHeight, 30.0f);
}

#pragma mark -

- (id) target {
	return target;
}

- (void) setTarget:(id) object {
	target = object;
}

#pragma mark -

- (SEL) action {
	return action;
}

- (void) setAction:(SEL) selector {
	action = selector;
}

#pragma mark -

- (void) mouseUp:(NSEvent *) event {
#pragma unused(event)
	if (target && action && [target respondsToSelector:action]) {
		[target performSelector:action withObject:self];
	}
}

@end
