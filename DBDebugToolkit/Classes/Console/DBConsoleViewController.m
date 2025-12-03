// The MIT License
//
// Copyright (c) 2016 Dariusz Bukowski
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "DBConsoleViewController.h"
#import "DBConsoleOutputCaptor.h"
#import "DBDeviceInfoProvider.h"

static NSString *const DBConsoleLogCellReuseIdentifier = @"DBConsoleLogCell";
static const NSInteger DBMaxConsoleLines = 2000;

@interface DBConsoleViewController () <UITableViewDataSource, UITableViewDelegate, DBConsoleOutputCaptorDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) DBConsoleOutputCaptor *consoleOutputCaptor;
@property (nonatomic, strong) DBDeviceInfoProvider *deviceInfoProvider;
@property (nonatomic, strong) NSArray<NSString *> *consoleLines;
@property (nonatomic, assign) BOOL isConsoleOutputPaused;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, assign) BOOL needsUpdate;

@end

@implementation DBConsoleViewController

#pragma mark - Initialization

- (instancetype)initWithConsoleOutputCaptor:(DBConsoleOutputCaptor *)consoleOutputCaptor
                         deviceInfoProvider:(DBDeviceInfoProvider *)deviceInfoProvider {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _consoleOutputCaptor = consoleOutputCaptor;
        _deviceInfoProvider = deviceInfoProvider;
        _isConsoleOutputPaused = NO;
        _needsUpdate = NO;
        _consoleLines = [self splitConsoleOutput:consoleOutputCaptor.consoleOutput];
    }
    return self;
}

- (void)dealloc {
    [_updateTimer invalidate];
    _consoleOutputCaptor.delegate = nil;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Console";
    self.view.backgroundColor = [UIColor whiteColor];

    [self setupTableView];
    [self setupNavigationBar];

    // Set up delegate
    self.consoleOutputCaptor.delegate = self;

    // Set up timer for batched updates (10 FPS max)
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                                      selector:@selector(updateTimerFired)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

#pragma mark - Setup

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 44.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:DBConsoleLogCellReuseIdentifier];

    [self.view addSubview:self.tableView];
}

- (void)setupNavigationBar {
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                 target:self
                                                                                 action:@selector(shareButtonTapped)];

    UIBarButtonItem *pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                                                 target:self
                                                                                 action:@selector(pauseButtonTapped)];

    UIBarButtonItem *clearButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                                 target:self
                                                                                 action:@selector(clearButtonTapped)];

    self.navigationItem.rightBarButtonItems = @[clearButton, pauseButton, shareButton];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.consoleLines.count > 0 ? self.consoleLines.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:DBConsoleLogCellReuseIdentifier forIndexPath:indexPath];

    // Configure cell
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:11.0] ?: [UIFont systemFontOfSize:11.0];

    if (self.consoleLines.count == 0) {
        cell.textLabel.text = @"No console output yet";
        cell.textLabel.textColor = [UIColor grayColor];
    } else {
        NSString *line = self.consoleLines[indexPath.row];
        cell.textLabel.text = line.length > 0 ? line : @" "; // Show empty line as space
        cell.textLabel.textColor = [UIColor blackColor];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.consoleLines.count > 0) {
        NSString *line = self.consoleLines[indexPath.row];
        UIPasteboard.generalPasteboard.string = line;

        // Show a brief flash to indicate copy
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        UIColor *originalColor = cell.backgroundColor;
        cell.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            cell.backgroundColor = originalColor;
        });
    }
}

#pragma mark - DBConsoleOutputCaptorDelegate

- (void)consoleOutputCaptorDidUpdateOutput:(DBConsoleOutputCaptor *)consoleOutputCaptor {
    if (!self.isConsoleOutputPaused) {
        self.needsUpdate = YES;
    }
}

- (void)consoleOutputCaptor:(DBConsoleOutputCaptor *)consoleOutputCaptor didSetEnabled:(BOOL)enabled {
    // Not used
}

#pragma mark - Timer

- (void)updateTimerFired {
    if (self.needsUpdate && !self.isConsoleOutputPaused) {
        self.needsUpdate = NO;
        [self updateConsoleLines];
    }
}

#pragma mark - Actions

- (void)shareButtonTapped {
    NSString *content = [NSString stringWithFormat:@"Device model: %@\nSystem version: %@\nConsole output:\n%@",
                        [self.deviceInfoProvider deviceModel] ?: @"unknown",
                        [self.deviceInfoProvider systemVersion] ?: @"unknown",
                        self.consoleOutputCaptor.consoleOutput];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[content]
                                                                             applicationActivities:nil];
    activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)pauseButtonTapped {
    self.isConsoleOutputPaused = !self.isConsoleOutputPaused;

    UIImage *image = self.isConsoleOutputPaused ?
        [UIImage systemImageNamed:@"play.circle"] :
        [UIImage systemImageNamed:@"pause.circle"];

    UIBarButtonItem *pauseButton = [[UIBarButtonItem alloc] initWithImage:image
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(pauseButtonTapped)];

    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (items.count >= 2) {
        items[1] = pauseButton;
        self.navigationItem.rightBarButtonItems = items;
    }
}

- (void)clearButtonTapped {
    [self.consoleOutputCaptor clearConsoleOutput];
    self.consoleLines = @[];
    [self.tableView reloadData];
}

#pragma mark - Helper Methods

- (void)updateConsoleLines {
    NSArray<NSString *> *newLines = [self splitConsoleOutput:self.consoleOutputCaptor.consoleOutput];

    if (![newLines isEqualToArray:self.consoleLines]) {
        self.consoleLines = newLines;
        [self.tableView reloadData];

        // Auto-scroll to bottom if there's content
        if (self.consoleLines.count > 0) {
            NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:self.consoleLines.count - 1 inSection:0];
            [self.tableView scrollToRowAtIndexPath:lastIndexPath
                                  atScrollPosition:UITableViewScrollPositionBottom
                                          animated:NO];
        }
    }
}

- (NSArray<NSString *> *)splitConsoleOutput:(NSString *)output {
    if (output.length == 0) {
        return @[];
    }

    NSArray<NSString *> *lines = [output componentsSeparatedByString:@"\n"];

    // Limit to max lines
    if (lines.count > DBMaxConsoleLines) {
        return [lines subarrayWithRange:NSMakeRange(lines.count - DBMaxConsoleLines, DBMaxConsoleLines)];
    }

    return lines;
}

@end
