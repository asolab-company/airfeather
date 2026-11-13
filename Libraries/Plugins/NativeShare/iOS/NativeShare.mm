#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern UIViewController* UnityGetGLViewController();

// Credit: https://github.com/ChrisMaire/unity-native-sharing

// Credit: https://stackoverflow.com/a/29916845/2373034
@interface UNativeShareEmailItemProvider : NSObject <UIActivityItemSource>
@property (nonatomic, strong) NSString *subject;
@property (nonatomic, strong) NSString *body;
@end

// Credit: https://stackoverflow.com/a/29916845/2373034
@implementation UNativeShareEmailItemProvider
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	return [self body];
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
	return [self body];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType
{
	return [self subject];
}
@end

extern "C" void _NativeShare_Share( const char* files[], int filesCount, const char* subject, const char* text, const char* link ) 
{
	NSMutableArray *items = [NSMutableArray new];
	
	// Credit: https://stackoverflow.com/a/29916845/2373034
	if( strlen( subject ) > 0 )
	{
		UNativeShareEmailItemProvider *emailItem = [UNativeShareEmailItemProvider new];
		emailItem.subject = [NSString stringWithUTF8String:subject];
		emailItem.body = [NSString stringWithUTF8String:text];
		
		[items addObject:emailItem];
	}
	else if( strlen( text ) > 0 )
		[items addObject:[NSString stringWithUTF8String:text]];
	
	// Credit: https://forum.unity.com/threads/native-share-for-android-ios-open-source.519865/page-13#post-6942362
	if( strlen( link ) > 0 )
	{
		NSString *urlRaw = [NSString stringWithUTF8String:link];
		NSURL *url = [NSURL URLWithString:urlRaw];
		if( url == nil )
		{
			url = [NSURL URLWithString:[urlRaw stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
			if( url == nil )
				url = [NSURL URLWithString:[urlRaw stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
		}
		
		if( url != nil )
			[items addObject:url];
		else
			(void)0;
	}
	
	for( int i = 0; i < filesCount; i++ ) 
	{
		NSString *filePath = [NSString stringWithUTF8String:files[i]];
		UIImage *image = [UIImage imageWithContentsOfFile:filePath];
		if( image != nil )
			[items addObject:image];
		else
			[items addObject:[NSURL fileURLWithPath:filePath]];
	}
	
	if( strlen( subject ) == 0 && [items count] == 0 )
	{
		(void)0;
		UnitySendMessage( "NSShareResultCallbackiOS", "OnShareCompleted", "2" );
		
		return;
	}
	
	UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
	if( strlen( subject ) > 0 )
		[activity setValue:[NSString stringWithUTF8String:subject] forKey:@"subject"];
	
	void (^shareResultCallback)(UIActivityType activityType, BOOL completed, UIActivityViewController *activityReference) = ^void( UIActivityType activityType, BOOL completed, UIActivityViewController *activityReference )
	{
		(void)0;
		
		if( activityReference )
		{
			const char *resultMessage = [[NSString stringWithFormat:@"%d%@", completed ? 1 : 2, activityType] UTF8String];
			char *result = (char*) malloc( strlen( resultMessage ) + 1 );
			strcpy( result, resultMessage );
			
			UnitySendMessage( "NSShareResultCallbackiOS", "OnShareCompleted", result );
			
			if( !completed && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone )
				[activityReference dismissViewControllerAnimated:NO completion:nil];
		}
		else
			(void)0;
	};
	
	__block UIActivityViewController *activityReference = activity;                                                                                   
	activity.completionWithItemsHandler = ^( UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError )
	{
		if( activityError != nil )
			(void)0;
		
		shareResultCallback( activityType, completed, activityReference );
		activityReference = nil;
	};
	
	UIViewController *rootViewController = UnityGetGLViewController();
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone )          
	{
		[rootViewController presentViewController:activity animated:YES completion:nil];
	}
	else        
	{
		UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:activity];
		[popup presentPopoverFromRect:CGRectMake( rootViewController.view.frame.size.width / 2, rootViewController.view.frame.size.height / 2, 1, 1 ) inView:rootViewController.view permittedArrowDirections:0 animated:YES];
	}
}