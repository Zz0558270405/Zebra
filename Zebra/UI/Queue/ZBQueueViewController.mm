//
//  ZBQueueViewController.m
//  Zebra
//
//  Created by Wilson Styres on 1/30/19.
//  Copyright © 2019 Wilson Styres. All rights reserved.
//

#import "ZBQueueViewController.h"

#import <UI/Packages/Views/Cells/ZBPackageTableViewCell.h>
#import <UI/Common/Views/ZBBoldTableViewHeaderView.h>
#import <UI/Console/ZBConsoleViewController.h>
#import <UI/ZBSidebarController.h>

#import <Plains/Model/PLPackage.h>
#import <Plains/Queue/PLQueue.h>

@interface ZBQueueViewController () {
    PLQueue *queue;
    NSDictionary <NSString *, NSArray <NSDictionary *> *> *issues;
    NSArray <NSArray <PLPackage *> *> *packages;
}
@end

@implementation ZBQueueViewController

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    
    if (self) {
        queue = [PLQueue sharedInstance];
        self.title = @"Queue";
        
        [self.tableView registerNib:[UINib nibWithNibName:@"ZBPackageTableViewCell" bundle:nil] forCellReuseIdentifier:@"packageTableViewCell"];
        [self.tableView registerNib:[UINib nibWithNibName:@"ZBBoldTableViewHeaderView" bundle:nil] forHeaderFooterViewReuseIdentifier:@"BoldTableViewHeaderView"];

        [self.tableView setTableHeaderView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 1)]];
        [self.tableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 1)]];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
#if TARGET_OS_IOS
    UIBarButtonItem *confirmButton = [[UIBarButtonItem alloc] initWithTitle:@"Confirm" style:UIBarButtonItemStyleDone target:self action:@selector(confirmButton:)];
    self.navigationItem.rightBarButtonItem = confirmButton;
    
    UIBarButtonItem *dismissButton = [[UIBarButtonItem alloc] initWithTitle:@"Dismiss" style:UIBarButtonItemStylePlain target:self action:@selector(goodbye)];
    self.navigationItem.leftBarButtonItem = dismissButton;
#endif
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQueue) name:PLQueueUpdateNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self->packages = queue.queuedPackages;
    self->issues = queue.issues;
    [self reloadData];
}

- (void)updateQueue {
    if ([self isViewLoaded]) {
        self->packages = queue.queuedPackages;
        self->issues = queue.issues;
        [self reloadData];
    }
}

- (void)goodbye {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table View Data Source

- (void)reloadData {
    [self.tableView reloadData];
    
    int count = 0;
    for (NSArray *arr in packages) {
        count += arr.count;
    }
    
    if (count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"No Packages In Queue";
        emptyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
        emptyLabel.textColor = [UIColor secondaryLabelColor];
        
        self.tableView.backgroundView = emptyLabel;
        
        [emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor].active = true;
        [emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor].active = true;
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false;
    } else {
        self.tableView.backgroundView = nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return packages.count + 1; // +1 for issues section
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { // Issues
        return issues.count;
    }
    
    section--;
    return packages[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger section = indexPath.section;
    if (section == 0) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"idk"];
    } else {
        section--;
        
        ZBPackageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"packageTableViewCell" forIndexPath:indexPath];
        
        PLPackage *package = packages[section][indexPath.row];
        cell.showVersion = YES;
        cell.showBadges = NO;
        
        [cell setPackage:package];
        
        if (issues[package.identifier]) {
            cell.accessoryType = UITableViewCellAccessoryDetailButton;
            cell.tintColor = [UIColor systemPinkColor];
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.tintColor = nil;
        }
        
        return cell;
    }
}

#pragma mark - Table View Delegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    ZBBoldTableViewHeaderView *cell = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"BoldTableViewHeaderView"];
    NSString *title;
    if (section == 0) {
        title = @"Issues";
    } else {
        section--;
        if (packages[section].count == 0) return NULL;
        switch (section) {
            case PLQueueInstall:
                title = @"Install";
                break;
            case PLQueueRemove:
                title = @"Remove";
                break;
            case PLQueueReinstall:
                title = @"Reinstall";
                break;
            case PLQueueUpgrade:
                title = @"Upgrade";
                break;
            case PLQueueDowngrade:
                title = @"Downgrade";
                break;
            default:
                title = @"Unknown";
                break;
        }
    }
    cell.titleLabel.text = title;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    if (section == 0) return 45;
    section--;
    if (packages[section].count == 0) return 0;
    return 45;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    PLPackage *package = self->packages[indexPath.section][indexPath.row];
    if ([queue canRemovePackage:package]) {
        UIContextualAction *clearAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Remove" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [self->queue removePackage:package];
            self->packages = self->queue.queuedPackages;
            [self reloadData];
        }];
        return [UISwipeActionsConfiguration configurationWithActions:@[clearAction]];
    }
    return NULL;
}

- (void)confirmButton:(id)sender {
    UIWindow *window = [UIApplication sharedApplication].windows[0];
    ZBConsoleViewController *console = [[ZBConsoleViewController alloc] init];
    if (window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        [[self navigationController] pushViewController:console animated:YES];
    } else {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:console];
        [self presentViewController:navController animated:YES completion:nil];
    }
}

#if TARGET_OS_MACCATALYST
- (NSArray *)toolbarItems {
    return @[@"confirmButton"];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
    int count = 0;
    for (NSArray *arr in packages) {
        count += arr.count;
    }
    return count;
}
#endif

@end
