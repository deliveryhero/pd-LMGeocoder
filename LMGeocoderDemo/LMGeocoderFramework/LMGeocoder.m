//
//  LMGeocoder.m
//  LMGeocoder
//
//  Created by LMinh on 31/05/2014.
//  Copyright (c) 2014 LMinh. All rights reserved.
//

#import "LMGeocoder.h"
#import "LMAddress.h"

static NSString * const kLMGeocoderErrorDomain = @"LMGeocoderError";

#define kGoogleAPIReverseGeocodingURL(lat, lng) [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true", lat, lng];
#define kGoogleAPIGeocodingURL(address)         [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=true", address];
#define kGoogleAPIPlaceDetailsURL(placeId)      [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?place_id=%@", placeId];
#define kGoogleAPIURLWithKey(url, key)          [NSString stringWithFormat:@"%@&key=%@", url, key];
// final format for country is e.g components=country:DE
#define countryCodeParam @"components=country"
#define languageParam @"language"
#define kGoogleAPIURLAppendCountry(url, params) [NSString stringWithFormat:@"%@&%@:%@", url, countryCodeParam, params];
#define kGoogleAPIURLAppendLanguage(url, params)[NSString stringWithFormat:@"%@&%@=%@", url, languageParam, params];

@interface LMGeocoder ()

@property (nonatomic, strong) CLGeocoder *appleGeocoder;
@property (nonatomic, strong) NSURLSessionDataTask *googleGeocoderTask;

@end

@implementation LMGeocoder

@synthesize isGeocoding = _isGeocoding;

#pragma mark - INIT

+ (LMGeocoder *)sharedInstance
{
    static LMGeocoder *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LMGeocoder alloc] init];
    });
    return sharedInstance;
}

+ (LMGeocoder *)geocoder
{
    return [[LMGeocoder alloc] init];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        self.appleGeocoder = [[CLGeocoder alloc] init];
    }
    return self;
}

#pragma mark - PlaceDetails

- (void)geocodePlaceId:(NSString *)placeId
               service:(LMGeocoderService)service
     completionHandler:(LMGeocodeCallback)handler {
    _isGeocoding = YES;

    // Check address string
    if (placeId == nil || placeId.length == 0) {
        NSError *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                             code:kLMGeocoderErrorInvalidAddressString
                                         userInfo:nil];
        _isGeocoding = NO;
        if (handler) {
            handler(nil, error);
        }
    } else {
        switch (service) {
            case kLMGeocoderGoogleService: {
                // Geocode using Google service
                NSString *urlString = kGoogleAPIPlaceDetailsURL(placeId);
                urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
                [self buildAsynchronousRequestFromURLString:urlString
                                          completionHandler:^(NSArray<LMAddress *> *_Nullable results, NSError *_Nullable error) {
                                              _isGeocoding = NO;
                                              if (handler) {
                                                  handler(results, error);
                                              }
                                          }];
                break;
            }
            case kLMGeocoderAppleService: {
                // TODO: Implement it later
                break;
            }
            default:
                break;
        }
    }
}

- (nullable NSArray *)geocodePlaceId:(NSString *)placeId
                                   service:(LMGeocoderService)service
                                     error:(NSError **)error {
    // Check address string
    if (placeId == nil || placeId.length == 0) {
        // Invalid address string --> Return
        *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                     code:kLMGeocoderErrorInvalidAddressString
                                 userInfo:nil];
        return nil;
    } else {
        // Valid address string --> Geocode using Google service
        NSString *urlString = kGoogleAPIPlaceDetailsURL(placeId);
        if (self.googleAPIKey != nil) {
            urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
        }
        NSArray *finalResults = [self buildSynchronousRequestFromURLString:urlString];
        return finalResults;
    }
}

#pragma mark - GEOCODE

- (void)geocodeAddressString:(NSString *)addressString
                     service:(LMGeocoderService)service
           completionHandler:(LMGeocodeCallback)handler {
    return [self geocodeAddressString:addressString
                        withinCountry:nil
                              service:service
                    completionHandler:handler];
}

- (void)geocodeAddressString:(NSString *)addressString
               withinCountry:(nullable NSString *)countryCode
                     service:(LMGeocoderService)service
           completionHandler:(LMGeocodeCallback)handler {
    _isGeocoding = YES;

    // Check address string
    if (addressString == nil || addressString.length == 0)
    {
        // Invalid address string --> Return error
        NSError *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                             code:kLMGeocoderErrorInvalidAddressString
                                         userInfo:nil];

        _isGeocoding = NO;
        if (handler) {
            handler(nil, error);
        }
    }
    else
    {
        // Valid address string --> Check service
        switch (service)
        {
            case kLMGeocoderGoogleService:
            {
                // Geocode using Google service
                NSString *urlString = kGoogleAPIGeocodingURL(addressString);
                if (self.googleAPIKey != nil) {
                    urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
                    if (countryCode != nil) {
                        urlString = kGoogleAPIURLAppendCountry(urlString, countryCode);
                    }
                }
                [self buildAsynchronousRequestFromURLString:urlString
                                          completionHandler:^(NSArray<LMAddress *> * _Nullable results, NSError * _Nullable error) {

                                              _isGeocoding = NO;
                                              if (handler) {
                                                  handler(results, error);
                                              }
                                          }];
                break;
            }
            case kLMGeocoderAppleService:
            {
                // Geocode using Apple service
                [self.appleGeocoder geocodeAddressString:addressString
                                       completionHandler:^(NSArray *placemarks, NSError *error) {

                                           _isGeocoding = NO;

                                           if (!error && placemarks.count) {
                                               // Request successful --> Parse response results
                                               NSArray *results = [self parseGeocodingResponseResults:placemarks service:kLMGeocoderAppleService];
                                               if (handler) {
                                                  handler(results, error);
                                               }
                                           }
                                           else {
                                               // Request failed --> Return error
                                               if (handler) {
                                                   handler(nil, error);
                                               }
                                           }
                                       }];
                break;
            }
            default:
                break;
        }
    }
}

- (nullable NSArray *)geocodeAddressString:(nonnull NSString *)addressString
                                   service:(LMGeocoderService)service
                                     error:(NSError **)error
{
    return [self geocodeAddressString:addressString
                        withinCountry:nil
                              service:service
                                error:error];
}

- (nullable NSArray *)geocodeAddressString:(nonnull NSString *)addressString
                             withinCountry:(nullable NSString *)countryCode
                                   service:(LMGeocoderService)service
                                     error:(NSError **)error
{
    // Check address string
    if (addressString == nil || addressString.length == 0)
    {
        // Invalid address string --> Return
        *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                     code:kLMGeocoderErrorInvalidAddressString
                                 userInfo:nil];
        return nil;
    }
    else
    {
        // Valid address string --> Geocode using Google service
        NSString *urlString = kGoogleAPIGeocodingURL(addressString);
        if (self.googleAPIKey != nil) {
            urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
        }
        if (countryCode != nil) {
            urlString = kGoogleAPIURLAppendCountry(urlString, countryCode);
        }
        NSArray *finalResults = [self buildSynchronousRequestFromURLString:urlString];
        return finalResults;
    }
}


#pragma mark - REVERSE GEOCODE

- (void)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                         service:(LMGeocoderService)service
               completionHandler:(LMGeocodeCallback)handler {
    return [self reverseGeocodeCoordinate:coordinate
                         withLanguageCode:nil
                                  service:service
                        completionHandler:handler];
}

- (void)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                withLanguageCode:(nullable NSString *)languageCode
                         service:(LMGeocoderService)service
               completionHandler:(LMGeocodeCallback)handler {
    _isGeocoding = YES;

    // Check location coordinate
    if (!CLLocationCoordinate2DIsValid(coordinate))
    {
        // Invalid location coordinate --> Return error
        NSError *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                             code:kLMGeocoderErrorInvalidCoordinate
                                         userInfo:nil];

        _isGeocoding = NO;
        if (handler) {
            handler(nil, error);
        }
    }
    else
    {
        // Valid location coordinate --> Check service
        switch (service)
        {
            case kLMGeocoderGoogleService:
            {
                // Reverse geocode using Google service
                NSString *urlString = kGoogleAPIReverseGeocodingURL(coordinate.latitude, coordinate.longitude);
                if (self.googleAPIKey != nil) {
                    urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
                }
                if (languageCode != nil) {
                    urlString = kGoogleAPIURLAppendLanguage(urlString, languageCode);
                }
                [self buildAsynchronousRequestFromURLString:urlString
                                          completionHandler:^(NSArray<LMAddress *> * _Nullable results, NSError * _Nullable error) {

                                              _isGeocoding = NO;
                                              if (handler) {
                                                  handler(results, error);
                                              }
                                          }];
                break;
            }
            case kLMGeocoderAppleService:
            {
                // Reverse geocode using Apple service
                CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                                  longitude:coordinate.longitude];
                [self.appleGeocoder reverseGeocodeLocation:location
                                         completionHandler:^(NSArray *placemarks, NSError *error) {

                                             _isGeocoding = NO;

                                             if (!error && placemarks.count) {
                                                 // Request successful --> Parse response results
                                                 NSArray *results = [self parseGeocodingResponseResults:placemarks service:kLMGeocoderAppleService];
                                                 if (handler) {
                                                    handler(results, error);
                                                 }
                                             }
                                             else {
                                                 // Request failed --> Return error
                                                 if (handler) {
                                                     handler(nil, error);
                                                 }
                                             }
                                         }];
                break;
            }
            default:
                break;
        }
    }
}

- (nullable NSArray *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                                       service:(LMGeocoderService)service
                                         error:(NSError **)error
{
    return [self reverseGeocodeCoordinate:coordinate
                         withLanguageCode:nil
                                  service:service
                                    error:error];
}

- (nullable NSArray *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                              withLanguageCode:(nullable NSString *)languageCode
                                       service:(LMGeocoderService)service
                                         error:(NSError **)error
{
    // Check location coordinate
    if (!CLLocationCoordinate2DIsValid(coordinate))
    {
        // Invalid location coordinate --> Return
        *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                     code:kLMGeocoderErrorInvalidCoordinate
                                 userInfo:nil];
        return nil;
    }
    else
    {
        // Valid location coordinate --> Reverse geocode using Google service
        NSString *urlString = kGoogleAPIReverseGeocodingURL(coordinate.latitude, coordinate.longitude);
        if (self.googleAPIKey != nil) {
            urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
        }
        if (languageCode != nil) {
            urlString = kGoogleAPIURLAppendLanguage(urlString, languageCode);
        }
        NSArray *finalResults = [self buildSynchronousRequestFromURLString:urlString];
        return finalResults;
    }
}


#pragma mark - CANCEL

- (void)cancelGeocode
{
    if (self.appleGeocoder) {
        [self.appleGeocoder cancelGeocode];
    }

    if (self.googleGeocoderTask) {
        [self.googleGeocoderTask cancel];
    }
}


#pragma mark - CONNECTION STUFF

- (void)buildAsynchronousRequestFromURLString:(NSString *)urlString
                            completionHandler:(LMGeocodeCallback)handler
{
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    self.googleGeocoderTask = [session dataTaskWithRequest:request
                                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

                                             if (!error && data)
                                             {
                                                 // Request successful --> Parse response to JSON
                                                 NSError *parsingError = nil;
                                                 NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                                                        options:NSJSONReadingAllowFragments
                                                                                                          error:&parsingError];
                                                 if (!parsingError && result)
                                                 {
                                                     // Parse successful --> Check status value
                                                     NSString *status = [result valueForKey:@"status"];
                                                     if ([status isEqualToString:@"OK"])
                                                     {
                                                         // Status OK --> Parse response results
                                                         NSArray *locationDicts = [result objectForKey:@"results"];
                                                         NSArray *finalResults = [self parseGeocodingResponseResults:locationDicts service:kLMGeocoderGoogleService];

                                                         if (handler) {
                                                             handler(finalResults, nil);
                                                         }
                                                     }
                                                     else
                                                     {
                                                         // Other statuses --> Return error
                                                         if (handler) {
                                                             handler(nil, error);
                                                         }
                                                     }
                                                 }
                                                 else
                                                 {
                                                     // Parse failed --> Return error
                                                     if (handler) {
                                                         handler(nil, error);
                                                     }
                                                 }
                                             }
                                             else
                                             {
                                                 // Request failed --> Return error
                                                 if (handler) {
                                                     handler(nil, error);
                                                 }
                                             }
                                         }];
    [self.googleGeocoderTask resume];
}

- (NSArray *)buildSynchronousRequestFromURLString:(NSString *)urlString
{
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];

    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (!error && data)
    {
        NSError *parsingError = nil;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingAllowFragments
                                                                 error:&parsingError];
        if (!parsingError && result)
        {
            NSString *status = [result objectForKey:@"status"];
            if ([status isEqualToString:@"OK"])
            {
                // Status OK --> Parse response results
                NSArray *locationDicts = [result objectForKey:@"results"];
                NSArray *finalResults = [self parseGeocodingResponseResults:locationDicts service:kLMGeocoderGoogleService];

                return finalResults;
            }
        }
    }

    return nil;
}


#pragma mark - PARSE RESULT DATA

- (NSArray *)parseGeocodingResponseResults:(NSArray *)responseResults service:(LMGeocoderService)service
{
    NSMutableArray *finalResults = [NSMutableArray new];

    for (id responseResult in responseResults) {
        LMAddress *address = [[LMAddress alloc] initWithLocationData:responseResult forServiceType:service];
        [finalResults addObject:address];
    }

    return finalResults;
}

@end
