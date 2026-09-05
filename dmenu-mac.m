/* See LICENSE for copyright and license details. */
#import <AppKit/AppKit.h>

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VERSION "0.1.0"

typedef struct {
  BOOL insensitive;
  BOOL top;
  BOOL bottom;
  BOOL message;
  BOOL prompt_only;
  BOOL return_early;
  NSInteger lines;
  CGFloat height;
  CGFloat min_width;
  CGFloat border_width;
  NSInteger monitor;
  NSTimeInterval timeout;
  NSString *prompt;
  NSString *font;
  NSColor *normal_bg;
  NSColor *normal_fg;
  NSColor *selected_bg;
  NSColor *selected_fg;
  NSColor *border;
  NSTextAlignment message_alignment;
} Options;

@class MenuController;

@interface ResultView : NSView
@property(nonatomic, weak) MenuController *menuController;
@end

@interface MenuPanel : NSPanel
@end

@interface MenuController
    : NSObject <NSApplicationDelegate, NSTextFieldDelegate>
@property(nonatomic) Options options;
@property(nonatomic, strong) NSArray<NSString *> *items;
@property(nonatomic, strong) NSArray<NSString *> *matches;
@property(nonatomic) NSInteger selection;
@property(nonatomic) NSInteger firstVisible;
@property(nonatomic) int status;
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) NSTextField *input;
@property(nonatomic, strong) ResultView *results;
- (instancetype)initWithOptions:(Options)options
                          items:(NSArray<NSString *> *)items;
- (BOOL)handleKeyEvent:(NSEvent *)event;
- (void)selectRelative:(NSInteger)delta;
- (void)acceptInput:(BOOL)typed keepOpen:(BOOL)keepOpen;
@end

static void die(const char *message) {
  fprintf(stderr, "dmenu-mac: %s\n", message);
  exit(EXIT_FAILURE);
}

static NSInteger integer_option(const char *option, const char *value) {
  char *end;
  errno = 0;
  long result = strtol(value, &end, 10);
  if (errno || !*value || *end || result < 0 || result > NSIntegerMax) {
    fprintf(stderr, "dmenu-mac: invalid value for %s: %s\n", option, value);
    exit(EXIT_FAILURE);
  }
  return (NSInteger)result;
}

static NSColor *color_option(const char *value) {
  if (!value || value[0] != '#' || (strlen(value) != 7 && strlen(value) != 9))
    die("colors must be #RRGGBB or #RRGGBBAA");
  char *end;
  unsigned long rgba = strtoul(value + 1, &end, 16);
  if (*end)
    die("colors must be #RRGGBB or #RRGGBBAA");
  if (strlen(value) == 7)
    rgba = rgba << 8 | 0xff;
  return [NSColor colorWithSRGBRed:((rgba >> 24) & 0xff) / 255.0
                             green:((rgba >> 16) & 0xff) / 255.0
                              blue:((rgba >> 8) & 0xff) / 255.0
                             alpha:(rgba & 0xff) / 255.0];
}

static void usage(void) {
  fputs("usage: dmenu-mac [options]\n"
        "  -b,  --bottom                  show a full-width bottom bar\n"
        "  -t,  --top                     show a full-width top bar\n"
        "  -i,  --insensitive             case-insensitive matching\n"
        "  -l,  --lines N                 number of visible result rows\n"
        "  -mw, --min-width N             minimum centered width (600)\n"
        "  -h,  --height N                row height (20)\n"
        "  -bw, --border-width N          border width (3)\n"
        "  -bc, --border-color COLOR      border color\n"
        "  -m,  --monitor N               screen index\n"
        "  -p,  --prompt TEXT             input prompt\n"
        "  -po, --prompt-only TEXT        prompt without reading stdin\n"
        "  -r,  --return-early            accept a sole match\n"
        "  -fn, --font-name FONT          font name\n"
        "  -nb, --normal-background COLOR normal background\n"
        "  -nf, --normal-foreground COLOR normal foreground\n"
        "  -sb, --selected-background C   selected background\n"
        "  -sf, --selected-foreground C   selected foreground\n"
        "  -e, -ec, -er                   display stdin as a message\n"
        "  -et, --echo-timeout SECS       message timeout\n"
        "  -v,  --version                 print version\n",
        stderr);
  exit(EXIT_FAILURE);
}

static const char *next_argument(int argc, char **argv, int *index) {
  if (++*index >= argc)
    usage();
  return argv[*index];
}

static NSString *string_argument(int argc, char **argv, int *index) {
  NSString *value =
      [NSString stringWithUTF8String:next_argument(argc, argv, index)];
  if (!value)
    die("option value is not valid UTF-8");
  return value;
}

static Options parse_options(int argc, char **argv) {
  Options options = {
      .lines = 20,
      .height = 20,
      .min_width = 600,
      .border_width = 3,
      .monitor = 0,
      .timeout = 3,
      .font = @"Menlo",
      .normal_bg = color_option("#000000f2"),
      .normal_fg = color_option("#ffffffff"),
      .selected_bg = color_option("#ffc87fff"),
      .selected_fg = color_option("#000000f2"),
      .border = color_option("#ffc87fff"),
      .message_alignment = NSTextAlignmentLeft,
  };

  for (int i = 1; i < argc; i++) {
    const char *arg = argv[i];
    if (!strcmp(arg, "-v") || !strcmp(arg, "--version")) {
      printf("dmenu-mac-%s\n", VERSION);
      exit(EXIT_SUCCESS);
    } else if (!strcmp(arg, "-b") || !strcmp(arg, "--bottom")) {
      options.bottom = YES;
    } else if (!strcmp(arg, "-t") || !strcmp(arg, "--top")) {
      options.top = YES;
    } else if (!strcmp(arg, "-i") || !strcmp(arg, "--insensitive")) {
      options.insensitive = YES;
    } else if (!strcmp(arg, "-r") || !strcmp(arg, "--return-early")) {
      options.return_early = YES;
    } else if (!strcmp(arg, "-e") || !strcmp(arg, "--echo")) {
      options.message = YES;
    } else if (!strcmp(arg, "-ec") || !strcmp(arg, "--echo-centre")) {
      options.message = YES;
      options.message_alignment = NSTextAlignmentCenter;
    } else if (!strcmp(arg, "-er") || !strcmp(arg, "--echo-right")) {
      options.message = YES;
      options.message_alignment = NSTextAlignmentRight;
    } else if (!strcmp(arg, "-l") || !strcmp(arg, "--lines")) {
      options.lines = integer_option(arg, next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-mw") || !strcmp(arg, "--min-width")) {
      options.min_width = integer_option(arg, next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-h") || !strcmp(arg, "--height")) {
      options.height = integer_option(arg, next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-bw") || !strcmp(arg, "--border-width")) {
      options.border_width = integer_option(arg, next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-m") || !strcmp(arg, "--monitor")) {
      options.monitor = integer_option(arg, next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-et") || !strcmp(arg, "--echo-timeout")) {
      options.timeout = integer_option(arg, next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-p") || !strcmp(arg, "--prompt")) {
      options.prompt = string_argument(argc, argv, &i);
    } else if (!strcmp(arg, "-po") || !strcmp(arg, "--prompt-only")) {
      options.prompt = string_argument(argc, argv, &i);
      options.prompt_only = YES;
    } else if (!strcmp(arg, "-fn") || !strcmp(arg, "--font-name")) {
      options.font = string_argument(argc, argv, &i);
    } else if (!strcmp(arg, "-nb") || !strcmp(arg, "--normal-background")) {
      options.normal_bg = color_option(next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-nf") || !strcmp(arg, "--normal-foreground")) {
      options.normal_fg = color_option(next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-sb") || !strcmp(arg, "--selected-background")) {
      options.selected_bg = color_option(next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-sf") || !strcmp(arg, "--selected-foreground")) {
      options.selected_fg = color_option(next_argument(argc, argv, &i));
    } else if (!strcmp(arg, "-bc") || !strcmp(arg, "--border-color")) {
      options.border = color_option(next_argument(argc, argv, &i));
    } else {
      usage();
    }
  }
  return options;
}

static NSArray<NSString *> *read_items(void) {
  NSData *data =
      [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
  NSString *input = [[NSString alloc] initWithData:data
                                          encoding:NSUTF8StringEncoding];
  if (!input)
    die("stdin is not valid UTF-8");
  NSMutableArray<NSString *> *items = [NSMutableArray array];
  [input enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    (void)stop;
    [items addObject:line];
  }];
  return items;
}

static NSFont *menu_font(NSString *description) {
  NSArray<NSString *> *parts = [description componentsSeparatedByString:@" "];
  CGFloat size = 14;
  NSString *name = description;
  if (parts.count > 1 && parts.lastObject.doubleValue > 0) {
    size = parts.lastObject.doubleValue;
    name = [[parts subarrayWithRange:NSMakeRange(0, parts.count - 1)]
        componentsJoinedByString:@" "];
  }
  return [NSFont fontWithName:name size:size]
             ?: [NSFont monospacedSystemFontOfSize:size
                                            weight:NSFontWeightRegular];
}

@implementation MenuPanel
- (BOOL)canBecomeKeyWindow {
  return YES;
}
@end

@implementation ResultView
- (BOOL)isFlipped {
  return YES;
}
- (BOOL)acceptsFirstResponder {
  return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  MenuController *menu = self.menuController;
  Options options = menu.options;
  [options.normal_bg setFill];
  NSRectFill(dirtyRect);
  if (!menu.matches.count)
    return;

  NSDictionary *normal = @{
    NSFontAttributeName : menu_font(options.font),
    NSForegroundColorAttributeName : options.normal_fg
  };
  NSDictionary *selected = @{
    NSFontAttributeName : menu_font(options.font),
    NSForegroundColorAttributeName : options.selected_fg
  };
  CGFloat padding = 10;

  if (options.lines) {
    NSInteger end =
        MIN((NSInteger)menu.matches.count, menu.firstVisible + options.lines);
    for (NSInteger i = menu.firstVisible; i < end; i++) {
      NSRect row = NSMakeRect(0, (i - menu.firstVisible) * options.height,
                              self.bounds.size.width, options.height);
      BOOL isSelected = i == menu.selection;
      [(isSelected ? options.selected_bg : options.normal_bg) setFill];
      NSRectFill(row);
      [menu.matches[i] drawInRect:NSInsetRect(row, padding, 2)
                   withAttributes:isSelected ? selected : normal];
    }
  } else {
    CGFloat x = 0;
    for (NSInteger i = menu.firstVisible; i < (NSInteger)menu.matches.count;
         i++) {
      CGFloat width =
          [menu.matches[i] sizeWithAttributes:normal].width + 2 * padding;
      if (x + width > self.bounds.size.width && x > 0)
        break;
      NSRect item = NSMakeRect(x, 0, width, options.height);
      BOOL isSelected = i == menu.selection;
      [(isSelected ? options.selected_bg : options.normal_bg) setFill];
      NSRectFill(item);
      [menu.matches[i] drawInRect:NSInsetRect(item, padding, 2)
                   withAttributes:isSelected ? selected : normal];
      x += width;
    }
  }
}
@end

@implementation MenuController
- (instancetype)initWithOptions:(Options)options
                          items:(NSArray<NSString *> *)items {
  if ((self = [super init])) {
    _options = options;
    _items = items;
    _matches = items;
    _selection = items.count ? 0 : -1;
    _status = EXIT_FAILURE;
  }
  return self;
}

- (NSScreen *)screen {
  NSArray<NSScreen *> *screens = NSScreen.screens;
  return self.options.monitor < (NSInteger)screens.count
             ? screens[self.options.monitor]
             : NSScreen.mainScreen;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  (void)notification;
  Options o = self.options;
  NSScreen *screen = [self screen];
  NSRect visible = screen.visibleFrame;
  NSFont *font = menu_font(o.font);
  CGFloat promptWidth =
      o.prompt.length
          ? [o.prompt sizeWithAttributes:@{NSFontAttributeName : font}].width +
                20
          : 0;
  CGFloat widest = 0;
  for (NSString *item in self.items)
    widest =
        MAX(widest,
            [item sizeWithAttributes:@{NSFontAttributeName : font}].width + 20);
  o.height =
      MAX(o.height, ceil(font.ascender - font.descender + font.leading) + 4);
  if (o.lines) {
    NSInteger available = MAX(
        1, floor((visible.size.height - 2 * o.border_width) / o.height) - 1);
    o.lines = MIN(o.lines, available);
  }
  self.options = o;
  NSInteger rows =
      o.message ? 1
                : 1 + (o.lines ? MIN(o.lines, (NSInteger)self.items.count) : 1);
  CGFloat width =
      o.top || o.bottom
          ? visible.size.width
          : MIN(visible.size.width,
                MAX(o.min_width, promptWidth + widest + 2 * o.border_width));
  CGFloat height =
      MIN(visible.size.height, rows * o.height + 2 * o.border_width);
  NSRect frame = NSMakeRect(NSMidX(visible) - width / 2,
                            NSMidY(visible) - height / 2, width, height);
  if (o.top)
    frame.origin = NSMakePoint(visible.origin.x, NSMaxY(visible) - height);
  else if (o.bottom)
    frame.origin = visible.origin;

  self.panel =
      [[MenuPanel alloc] initWithContentRect:frame
                                   styleMask:NSWindowStyleMaskBorderless
                                     backing:NSBackingStoreBuffered
                                       defer:NO];
  self.panel.level = NSStatusWindowLevel;
  self.panel.opaque = o.normal_bg.alphaComponent == 1;
  self.panel.backgroundColor = o.border;
  self.panel.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace |
                                  NSWindowCollectionBehaviorFullScreenAuxiliary;
  self.panel.hidesOnDeactivate = YES;
  self.panel.releasedWhenClosed = NO;

  NSView *content = self.panel.contentView;
  NSRect inner = NSInsetRect(content.bounds, o.border_width, o.border_width);
  if (o.message) {
    NSTextField *label =
        [NSTextField labelWithString:self.items.firstObject ?: @""];
    label.frame = inner;
    label.font = font;
    label.textColor = o.normal_fg;
    label.backgroundColor = o.normal_bg;
    label.drawsBackground = YES;
    label.alignment = o.message_alignment;
    [content addSubview:label];
    [self performSelector:@selector(finishMessage)
               withObject:nil
               afterDelay:o.timeout];
  } else {
    promptWidth = MIN(promptWidth, MAX(0, inner.size.width - 60));
    CGFloat inputY = inner.size.height - o.height;
    if (o.prompt.length) {
      NSTextField *prompt = [NSTextField labelWithString:o.prompt];
      prompt.frame = NSMakeRect(inner.origin.x, inputY, promptWidth, o.height);
      prompt.font = font;
      prompt.textColor = o.selected_fg;
      prompt.backgroundColor = o.selected_bg;
      prompt.drawsBackground = YES;
      prompt.alignment = NSTextAlignmentCenter;
      [content addSubview:prompt];
    }
    self.input = [[NSTextField alloc]
        initWithFrame:NSMakeRect(inner.origin.x + promptWidth, inputY,
                                 inner.size.width - promptWidth, o.height)];
    self.input.bordered = NO;
    self.input.focusRingType = NSFocusRingTypeNone;
    self.input.font = font;
    self.input.textColor = o.normal_fg;
    self.input.backgroundColor = o.normal_bg;
    self.input.delegate = self;
    [content addSubview:self.input];

    self.results = [[ResultView alloc]
        initWithFrame:NSMakeRect(inner.origin.x, inner.origin.y,
                                 inner.size.width,
                                 MAX(0, inner.size.height - o.height))];
    self.results.menuController = self;
    [content addSubview:self.results];
  }

  [NSApp activateIgnoringOtherApps:YES];
  [self.panel makeKeyAndOrderFront:nil];
  if (self.input)
    [self.panel makeFirstResponder:self.input];
  if (o.return_early && self.matches.count == 1)
    [self acceptInput:NO keepOpen:NO];
}

- (void)applicationDidResignActive:(NSNotification *)notification {
  (void)notification;
  [self.panel orderOut:nil];
  [NSApp stop:nil];
}

- (void)finishMessage {
  self.status = EXIT_SUCCESS;
  [self.panel orderOut:nil];
  [NSApp stop:nil];
}

- (void)controlTextDidChange:(NSNotification *)notification {
  (void)notification;
  NSString *query = self.input.stringValue;
  NSArray<NSString *> *tokens =
      [query componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                      whitespaceCharacterSet]];
  NSString *firstToken = @"";
  for (NSString *token in tokens) {
    if (token.length) {
      firstToken = token;
      break;
    }
  }
  NSStringCompareOptions compare =
      self.options.insensitive ? NSCaseInsensitiveSearch : 0;
  NSMutableArray *exact = [NSMutableArray array];
  NSMutableArray *prefix = [NSMutableArray array];
  NSMutableArray *substring = [NSMutableArray array];
  for (NSString *item in self.items) {
    BOOL found = YES;
    for (NSString *token in tokens) {
      if (token.length &&
          [item rangeOfString:token options:compare].location == NSNotFound) {
        found = NO;
        break;
      }
    }
    if (!found)
      continue;
    if ([item compare:query options:compare] == NSOrderedSame)
      [exact addObject:item];
    else if (firstToken.length &&
             [item rangeOfString:firstToken options:compare].location == 0)
      [prefix addObject:item];
    else
      [substring addObject:item];
  }
  [exact addObjectsFromArray:prefix];
  [exact addObjectsFromArray:substring];
  self.matches = exact;
  self.selection = exact.count ? 0 : -1;
  self.firstVisible = 0;
  [self.results setNeedsDisplay:YES];
  if (self.options.return_early && exact.count == 1)
    [self acceptInput:NO keepOpen:NO];
}

- (void)selectRelative:(NSInteger)delta {
  if (!self.matches.count)
    return;
  self.selection =
      MAX(0, MIN((NSInteger)self.matches.count - 1, self.selection + delta));
  if (self.options.lines) {
    if (self.selection < self.firstVisible)
      self.firstVisible = self.selection;
    else if (self.selection >= self.firstVisible + self.options.lines)
      self.firstVisible = self.selection - self.options.lines + 1;
  } else
    self.firstVisible = self.selection;
  [self.results setNeedsDisplay:YES];
}

- (void)acceptInput:(BOOL)typed keepOpen:(BOOL)keepOpen {
  NSString *value = typed || self.selection < 0 ? self.input.stringValue
                                                : self.matches[self.selection];
  fputs(value.UTF8String, stdout);
  fputc('\n', stdout);
  fflush(stdout);
  self.status = EXIT_SUCCESS;
  if (!keepOpen) {
    [self.panel orderOut:nil];
    [NSApp stop:nil];
  }
}

- (BOOL)handleKeyEvent:(NSEvent *)event {
  if (!self.input)
    return NO;
  NSEventModifierFlags flags =
      event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
  BOOL control = flags & NSEventModifierFlagControl;
  NSString *key = event.charactersIgnoringModifiers.lowercaseString;
  if (control && ([key isEqualToString:@"j"] || [key isEqualToString:@"k"])) {
    [self selectRelative:[key isEqualToString:@"j"] ? 1 : -1];
    return YES;
  }
  if (control && ([key isEqualToString:@"c"] || [key isEqualToString:@"g"])) {
    [self.panel orderOut:nil];
    [NSApp stop:nil];
    return YES;
  }
  switch (event.keyCode) {
  case 125:
    [self selectRelative:1];
    return YES;
  case 126:
    [self selectRelative:-1];
    return YES;
  case 116:
    [self selectRelative:-MAX(self.options.lines, 1)];
    return YES;
  case 121:
    [self selectRelative:MAX(self.options.lines, 1)];
    return YES;
  case 36:
    [self acceptInput:(flags & NSEventModifierFlagShift) keepOpen:control];
    return YES;
  case 48:
    if (self.selection >= 0) {
      self.input.stringValue = self.matches[self.selection];
      [self controlTextDidChange:nil];
    }
    return YES;
  case 53:
    [self.panel orderOut:nil];
    [NSApp stop:nil];
    return YES;
  default:
    return NO;
  }
}
@end

int main(int argc, char **argv) {
  @autoreleasepool {
    Options options = parse_options(argc, argv);
    NSArray<NSString *> *items = options.prompt_only ? @[] : read_items();
    NSApplication *application = [NSApplication sharedApplication];
    [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
    MenuController *controller = [[MenuController alloc] initWithOptions:options
                                                                   items:items];
    application.delegate = controller;
    [NSEvent
        addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                     handler:^NSEvent *(NSEvent *event) {
                                       return [controller handleKeyEvent:event]
                                                  ? nil
                                                  : event;
                                     }];
    [application run];
    return controller.status;
  }
}
