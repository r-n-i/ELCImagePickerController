//
//  AlbumPickerController.m
//
//  Created by ELC on 2/15/11.
//  Copyright 2011 ELC Technologies. All rights reserved.
//

#import "ELCAlbumPickerController.h"
#import "ELCImagePickerController.h"
#import "ELCAssetTablePicker.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>

@interface ELCAlbumPickerController () <PHPhotoLibraryChangeObserver>

@end

@implementation ELCAlbumPickerController

//Using auto synthesizers

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
	
	[self.navigationItem setTitle:NSLocalizedString(@"Loading...", nil)];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self.parent action:@selector(cancelImagePicker)];
	[self.navigationItem setRightBarButtonItem:cancelButton];

    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
	self.assetGroups = tempArray;
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [self loadAlbums];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *errorMessage = NSLocalizedString(@"This app does not have access to your photos or videos. You can enable access in Privacy Settings.", nil);
                [self showAlertWithTitle:NSLocalizedString(@"Access Denied", nil)
                                              message:errorMessage
                                         cancelButton:NSLocalizedString(@"Ok", nil)
                                       fromController:self];
                [self.navigationItem setTitle:nil];[self.navigationItem setTitle:nil];
            });
        }
    }];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [PHPhotoLibrary.sharedPhotoLibrary unregisterChangeObserver:self];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    [self reloadTableView];
}

- (void)loadAlbums {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSNumber *filter = [self assetFilter];
            PHFetchOptions *assetsFilter = [[PHFetchOptions alloc] init];
            assetsFilter.predicate = [ELCAsset slowmoFilterPredicate];
            if (filter) {
                NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[assetsFilter.predicate, [ELCAsset assetFilterPredicate:filter.integerValue]]];
                assetsFilter.predicate = predicate;
            }
            NSArray *collectionsFetchResults;
            
            PHFetchResult *smartAlbums = [PHAssetCollection       fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                                        subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
            PHFetchResult *syncedAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                                   subtype:PHAssetCollectionSubtypeAlbumSyncedAlbum options:nil];
            PHFetchResult *userCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
            
            // Add each PHFetchResult to the array
            collectionsFetchResults = @[smartAlbums, userCollections, syncedAlbums];
            
            for (int i = 0; i < collectionsFetchResults.count; i ++) {
                
                PHFetchResult *fetchResult = collectionsFetchResults[i];
                
                for (int x = 0; x < fetchResult.count; x ++) {
                    
                    PHAssetCollection *collection = fetchResult[x];
                    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:assetsFilter];
                    if (assetsFetchResult.count > 0) {
                        NSString *sGroupPropertyName = collection.localizedTitle;
                        
                        if ([[sGroupPropertyName lowercaseString] isEqualToString:@"camera roll"] ) {
                            [self.assetGroups insertObject:collection atIndex:0];
                        }
                        else {
                            [self.assetGroups addObject:collection];
                        }
                    }
                    
                }
            }
            [self performSelectorOnMainThread:@selector(reloadTableView) withObject:nil waitUntilDone:YES];
        }
    });
}

- (void)reloadTableView
{
	[self.tableView reloadData];
	[self.navigationItem setTitle:NSLocalizedString(@"Select an Album", nil)];
}

- (BOOL)shouldSelectAsset:(ELCAsset *)asset previousCount:(NSUInteger)previousCount
{
    return [self.parent shouldSelectAsset:asset previousCount:previousCount];
}

- (BOOL)shouldDeselectAsset:(ELCAsset *)asset previousCount:(NSUInteger)previousCount
{
    return [self.parent shouldDeselectAsset:asset previousCount:previousCount];
}

- (void)selectedAssets:(NSArray*)assets
{
	[_parent selectedAssets:assets];
}

- (NSNumber *)assetFilter
{
    if([self.mediaTypes containsObject:(NSString *)kUTTypeImage] && [self.mediaTypes containsObject:(NSString *)kUTTypeMovie])
    {
        return nil;
    }
    else if([self.mediaTypes containsObject:(NSString *)kUTTypeMovie])
    {
        return @(PHAssetMediaTypeVideo);
    }
    else
    {
        return @(PHAssetMediaTypeImage);
    }
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.assetGroups count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSNumber *filter = [self assetFilter];
    PHFetchOptions *assetsFilter = [[PHFetchOptions alloc] init];
    assetsFilter.predicate = [ELCAsset slowmoFilterPredicate];
    if (filter) {
        NSCompoundPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[assetsFilter.predicate, [ELCAsset assetFilterPredicate:filter.integerValue]]];
        assetsFilter.predicate = predicate;
    }
    
    // Get count
    PHAssetCollection *g = (PHAssetCollection*)[self.assetGroups objectAtIndex:indexPath.row];
    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:g options:assetsFilter];
    NSInteger gCount = assetsFetchResult.count;
    
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    [[PHImageManager defaultManager] requestImageForAsset:assetsFetchResult.firstObject targetSize:CGSizeMake(156,156) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = YES;
        [cell.imageView setImage:result];
    }];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%ld)",g.localizedTitle, (long)gCount];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    return cell;
}

// Resize a UIImage. From http://stackoverflow.com/questions/2658738/the-simplest-way-to-resize-an-uiimage
- (UIImage *)resize:(UIImage *)image to:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	ELCAssetTablePicker *picker = [[ELCAssetTablePicker alloc] initWithNibName: nil bundle: nil];
	picker.parent = self;

    picker.assetGroup = [self.assetGroups objectAtIndex:indexPath.row];
    [picker setAssetsFilter:[self assetFilter]];
    
	picker.assetPickerFilterDelegate = self.assetPickerFilterDelegate;
	
	[self.navigationController pushViewController:picker animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 95;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message cancelButton:(NSString *)cancel fromController:(UIViewController*)controller {
    UIAlertController* alertView = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    if (cancel.length > 0) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:nil];
        [alertView addAction:cancelAction];
    }
    self.popoverPresentationController.sourceView = controller.view;
    self.popoverPresentationController.sourceRect = controller.view.frame;
    self.popoverPresentationController.permittedArrowDirections = 0;
    [controller presentViewController:self animated:YES completion:nil];
}

@end

