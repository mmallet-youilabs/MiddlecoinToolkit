//
//  FirstViewController.m
//  Middlecoin Toolkit
//
//  Created by Mathieu Mallet on 1/18/2014.
//  Copyright (c) 2014 Equinox Synthetics. All rights reserved.
//

#import "UserStatsController.h"

@interface UserStatsController ()

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@property (weak, nonatomic) IBOutlet UILabel *balanceLabel;
@property (weak, nonatomic) IBOutlet UILabel *immatureLabel;
@property (weak, nonatomic) IBOutlet UILabel *unexchangedLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalUnpaidLabel;
@property (weak, nonatomic) IBOutlet UILabel *hashRateLabel;
@property (weak, nonatomic) IBOutlet UILabel *rejectRateLabel;
@property (weak, nonatomic) IBOutlet UILabel *payoutDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *payoutAmountLabel;
@property (weak, nonatomic) IBOutlet UILabel *payoutAddressLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalPaidOutLabel;
@property (weak, nonatomic) IBOutlet UILabel *averageRateLabel;
@property (weak, nonatomic) IBOutlet UILabel *updateDateLabel;

@end

@implementation UserStatsController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self refresh:nil];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (Boolean)isPoolPage
{
    return [self.title isEqualToString:@"Pool Stats"];
}

- (IBAction)refresh:(id)sender {
    if ([self isPoolPage])
    {
        [self setAllValuesTo:@"Loading..."];
        [self loadDataFor:nil];
    }
    else
    {
        NSString *address = [[NSUserDefaults standardUserDefaults] valueForKey:@"userPayoutAddress"];
        
        if (![self isValidAddress:address])
        {
            [self setWebViewTextTo:@"<h1>No user payout address configured. Configure your payout address in the Settings tab to view user stats.</h1>"];
            [self setAllValuesTo:@"Error"];
            
            [self showNoPayoutAddressConfiguredError];
        }
        else
        {
            [self setAllValuesTo:@"Loading..."];
            [self loadDataFor:address];
        }
    }
}

- (Boolean)isValidAddress:(NSString*)address
{
    if (address == nil)
        return false;
    //if ([address isEqualToString:@"1"])
    //    return false;
    //if ([address isEqualToString:@""])
    //    return false;
    if ([address length] != 34)
        return false;
    if ([address characterAtIndex:0] != '1')
        return false;
    
    return true;
}

- (void)setWebViewTextTo:(NSString*)text
{
    [self.webView loadHTMLString:text baseURL:nil];
}

- (IBAction)showStatsInSafari:(id)sender {
    if ([self isPoolPage])
    {
        NSURL *htmlUrl = [NSURL URLWithString:@"http://www.middlecoin.com"];
        [[UIApplication sharedApplication] openURL:htmlUrl];
    }
    else
    {
        NSString *address = [[NSUserDefaults standardUserDefaults] valueForKey:@"userPayoutAddress"];
        if (![self isValidAddress:address])
        {
            [self showNoPayoutAddressConfiguredError];
        }
        else
        {
            NSURL *htmlUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://middlecoin2.s3-website-us-west-2.amazonaws.com/reports/%@.html", address]];
            [[UIApplication sharedApplication] openURL:htmlUrl];
        }
    }
}

- (void)showNoPayoutAddressConfiguredError
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:nil message:@"A  payout address must first be configured in the settings tab." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)loadDataFor:(NSString*)payoutAddress
{
    Boolean isPool = [self isPoolPage];
    NSURL *htmlUrl;
    if (isPool)
        htmlUrl = [NSURL URLWithString:@"http://www.middlecoin.com"];
    else
        htmlUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://middlecoin2.s3-website-us-west-2.amazonaws.com/reports/%@.html", payoutAddress]];
    //NSLog(@"loading data from %@...", htmlUrl);
    
    NSError *error = nil;
    NSString *htmlData = [NSString stringWithContentsOfURL:htmlUrl encoding:NSUTF8StringEncoding error:&error];
    
    if (!htmlData)
    {
         [self setWebViewTextTo:[NSString stringWithFormat:@"<h1>Failed to load HTML data due to error: %@</h1>", error.localizedDescription]];
        [self setAllValuesTo:@"Error"];
        return;
    }
    
    // HTML data successfully loaded. Now do some parsing.
    
    // Get Javascript URL
    NSURL *jsUrl = [NSURL URLWithString:[self extractStringFromHTML:htmlData usingRegex:@".*<script .*\"(http://.*)\"></script>.*" getLast:false]];
    if (jsUrl == nil)
    {
        [self setWebViewTextTo:@"Failed to parse received HTML data."];
        [self setAllValuesTo:@"N/A"];
        return;
    }
    
    // Now parse the other stuff on the HTML page (e.g. last payout amount and last update date)
    
    self.payoutAddressLabel.text = payoutAddress;
    // Get last payout amount
    NSString *lastPayoutAmountString = [self extractStringFromHTML:htmlData
                                                        usingRegex:@"m.</td>\n<td>(.*)</td>\n</tr>" getLast:true];
    self.payoutAmountLabel.text = [lastPayoutAmountString stringByAppendingString:@" BTC"];

    NSString *lastPayoutDateString = [self extractStringFromHTML:htmlData
                                                        usingRegex:@"</td>\n<td>(.*)</td>\n<td>" getLast:true];
    self.payoutDateLabel.text = [self convertToLocalDate:lastPayoutDateString];
    
    if (isPool)
    {
        NSString *totalPaidOutString = [self extractStringFromHTML:htmlData
                                                        usingRegex:@"<td>(.*)</td>\n</tr>" getLast:true];
        self.totalPaidOutLabel.text = [totalPaidOutString stringByAppendingString:@" BTC"];
    }
    else
    {
        NSString *totalPaidOutString = [self extractStringFromHTML:htmlData
                                                    usingRegex:@"<td>(.*)</a></td>\n</tr>" getLast:true];
        self.totalPaidOutLabel.text = [totalPaidOutString stringByAppendingString:@" BTC"];
    }


    
    // Now download the javascript data.
    NSString *jsData = [NSString stringWithContentsOfURL:jsUrl encoding:NSUTF8StringEncoding error:&error];
    
    jsData = [jsData stringByReplacingOccurrencesOfString:@"ctx.fillRect(940+1,0,1000,20-4);" withString:@"ctx.clearRect(940+1,0,1000,20-4);"];

    
    if ([@"" isEqualToString:jsData])
    {
        [self setWebViewTextTo:@"<h1>Failed to load graph data.</h1>"];
        [self setAllValuesTo:@"Error"];
        return;
    }
    
    if (!jsData)
    {
        [self setWebViewTextTo:[NSString stringWithFormat:@"<h1>Failed to load graph data due to error: %@</h1>", error.localizedDescription]];
        [self setAllValuesTo:@"Error"];
        return;
    }
    
    // Make a 'fake' web page and include JS data in it
    NSString *myHTML = [[@"<html><body><canvas id=\"mc_data\" width=\"1000\" height=\"400\" style=\"border:1px solid; margin: 0px 10px 0px 0px\">Hm no HTML canvas graphics support??</canvas><script type=\"text/javascript\">" stringByAppendingString:jsData] stringByAppendingString:@"</script></html></body>"];
    [self setWebViewTextTo:myHTML];
    
    // Parse the JS data
    
    NSString *immatureString = [self extractStringFromHTML:jsData
                                                    usingRegex:@"Immature:.*?txt=' (.*?) *'" getLast:false];
    self.immatureLabel.text = [immatureString stringByAppendingString:@" BTC"];

    NSString *unexchangedString = [self extractStringFromHTML:jsData
                                                usingRegex:@"Unexchanged:.*?txt=' (.*?) *'" getLast:false];
    self.unexchangedLabel.text = [unexchangedString stringByAppendingString:@" BTC"];
    
    NSString *balanceString = [self extractStringFromHTML:jsData
                                                   usingRegex:@"Balance:.*?txt=' (.*?) *'" getLast:false];
    self.balanceLabel.text = [balanceString stringByAppendingString:@" BTC"];
    
    NSString *acceptedString = [self extractStringFromHTML:jsData
                                               usingRegex:@"Accepted:.*?txt=' (.*?) *'" getLast:false];
    self.hashRateLabel.text = acceptedString;
    
    NSString *rejectedString = [self extractStringFromHTML:jsData
                                                usingRegex:@"Rejected:.*?txt=' (.*?) *'" getLast:false];
    self.rejectRateLabel.text = rejectedString;

    NSString *averageHashString = [self extractStringFromHTML:jsData
                                                usingRegex:@"Three Hour Moving Average:.*?txt=' (.*?) *'" getLast:false];
    self.averageRateLabel.text = averageHashString;
    
    // Extract update date from graph
    NSString *updateDateString = [self extractStringFromHTML:jsData
                                                   usingRegex:@"Latest Values in BTC at (.*?) UTC" getLast:false];
    self.updateDateLabel.text = [self convertToLocalDateAlt:updateDateString];
    
    // Calcualte approximate total unpaid
    double unpaid = [balanceString doubleValue] + [immatureString doubleValue] + [unexchangedString doubleValue];
    self.totalUnpaidLabel.text = [NSString stringWithFormat:@"%1.8f BTC", unpaid];
}

-(NSString*) convertToLocalDate:(NSString*)utcDate
{
    // Start by converting date to something we can work with
    NSString *date = [utcDate stringByReplacingOccurrencesOfString:@"." withString:@""];
    //NSLog(@"String to work with: %@", date);
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [formatter setDateFormat:@"MMM d, yyyy, h:mm a"];
    
    NSDate *parsed = [formatter dateFromString:date];
    //NSLog(@"parsed date: %@", parsed);
    
    NSDateFormatter* outputFormatter = [[NSDateFormatter alloc] init];
    [outputFormatter setDateStyle:NSDateFormatterMediumStyle];
    [outputFormatter setTimeStyle:NSDateFormatterShortStyle];
    NSString* myString = [outputFormatter stringFromDate:parsed];
    
    return myString;
}

-(NSString*) convertToLocalDateAlt:(NSString*)utcDate
{
    // Start by converting date to something we can work with
    NSString *date = utcDate;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [formatter setDateFormat:@"MM/dd/yy HH:mm"];
    
    NSDate *parsed = [formatter dateFromString:date];
    
    NSDateFormatter* outputFormatter = [[NSDateFormatter alloc] init];
    [outputFormatter setDateStyle:NSDateFormatterMediumStyle];
    [outputFormatter setTimeStyle:NSDateFormatterShortStyle];
    NSString* myString = [outputFormatter stringFromDate:parsed];
    
    return myString;
}

-(NSString*) extractStringFromHTML:(NSString*)html usingRegex:(NSString*)regex getLast:(bool)useLast
{
    NSError *error = nil;
    NSRegularExpression *jsExpr = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *matches = [jsExpr matchesInString:html options:0 range:NSMakeRange(0, [html length])];
    NSString *result = nil;
    for (NSTextCheckingResult *match in matches)
    {
        NSRange groupRange = [match rangeAtIndex:1];
        result = [html substringWithRange:groupRange];
        if (!useLast)
            return result;
    }
    
    return result;
}

- (void)setAllValuesTo:(NSString*)value
{
    self.balanceLabel.text = value;
    self.immatureLabel.text = value;
    self.unexchangedLabel.text = value;
    self.totalUnpaidLabel.text = value;
    self.hashRateLabel.text = value;
    self.rejectRateLabel.text = value;
    self.payoutDateLabel.text = value;
    self.payoutAmountLabel.text = value;
    self.payoutAddressLabel.text = value;
    self.totalPaidOutLabel.text = value;
    self.totalUnpaidLabel.text = value;
    self.averageRateLabel.text = value;
    self.updateDateLabel.text = value;
}

@end