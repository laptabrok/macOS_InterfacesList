//
//  main.m
//  network_interfaces
//
//  Created by Igor Ivanov on 13.11.2019.
//  Copyright © 2019 Igor Ivanov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if_dl.h>
#include <ifaddrs.h>
#include <vector>
#include <string>

// https://stackoverflow.com/questions/40695674/thunderbolt-to-ethernet-adapter-not-found-in-swift-using-getifaddrs
// https://src-bin.com/en/q/e3e54

std::vector<std::string> listNetworkInterfaces() {
	std::vector<std::string>	result_wireless;
	std::vector<std::string>	result_wired;

	CFStringRef					stringRef			= nil;
	NSString					*bsdName			= nil;	// en0, bridge0 etc.
	NSString					*displayName		= nil;	// Wi-Fi, Bluetooth PAN, Thunderbolt 1, Thunderbolt Bridge, Apple USB Ethernet Adapter etc.
	NSString					*hardwareAddress	= nil;	// MAC address actually
	NSString					*interfaceType		= nil;	// Ethernet, IEEE80211 etc.

	NSArray                 	*allInterfaces      = (NSArray*)SCNetworkInterfaceCopyAll();
    NSEnumerator            	*interfaceWalker    = [allInterfaces objectEnumerator];
    SCNetworkInterfaceRef   	curInterface        = nil;

	NSStringCompareOptions		searchOptions		= NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;

    while ( curInterface = (SCNetworkInterfaceRef)[interfaceWalker nextObject] ) {
		// Check BSD type
		stringRef = SCNetworkInterfaceGetBSDName(curInterface);
		if (stringRef == nil) continue;
		bsdName = (NSString*)stringRef;

		// Check localized display name
		stringRef = SCNetworkInterfaceGetLocalizedDisplayName(curInterface);
		if (stringRef == nil) continue;
		displayName = (NSString*)stringRef;
		if ([displayName localizedCaseInsensitiveContainsString:@"USB"] ||
			[displayName localizedCaseInsensitiveContainsString:@"Bluetooth"] ||
			[displayName localizedCaseInsensitiveContainsString:@"Thunderbolt Bridge"]) {

			continue;
		}

		// Get MAC address
		stringRef = SCNetworkInterfaceGetHardwareAddressString(curInterface);
		if (stringRef == nil) continue;
		hardwareAddress = (NSString*)stringRef;

		// Check interface type
		stringRef = SCNetworkInterfaceGetInterfaceType(curInterface);
		if (stringRef == nil) continue;
		interfaceType = (NSString*)stringRef;
		if ([interfaceType rangeOfString:@"IEEE80211" options:searchOptions].location != NSNotFound)
			result_wireless.push_back(std::string([hardwareAddress UTF8String]));
		else if ([interfaceType rangeOfString:@"Ethernet" options:searchOptions].location != NSNotFound)
			result_wired.push_back(std::string([hardwareAddress UTF8String]));
		else
			continue;

		NSLog(@"----------------------------------");
		NSLog(@"BSD name:         %@", displayName);
		NSLog(@"Display name:     %@", bsdName);
		NSLog(@"Interface type:   %@", interfaceType);
		NSLog(@"Interface type:   %@", hardwareAddress);
    }

	std::sort(result_wireless.begin(), result_wireless.end(), [] (std::string& mac1, std::string& mac2) { return mac1 < mac2; });
	std::sort(result_wired.begin(), result_wired.end(), [] (std::string& mac1, std::string& mac2) { return mac1 < mac2; });

	std::vector<std::string> result;
	result.reserve(result_wireless.size() + result_wired.size());
	for (std::string& mac : result_wireless) result.emplace_back(mac);
	for (std::string& mac : result_wired) result.emplace_back(mac);
//	for (const auto& mac : result) NSLog(@"%s", mac.c_str());

	return result;
}

int listInterfacesMACs(void) {
    struct ifaddrs *ifap, *ifaptr;
    unsigned char *ptr;

    if (getifaddrs(&ifap) == 0) {
        for(ifaptr = ifap; ifaptr != NULL; ifaptr = (ifaptr)->ifa_next) {
            if (((ifaptr)->ifa_addr)->sa_family == AF_LINK) {
                ptr = (unsigned char *)LLADDR((struct sockaddr_dl *)(ifaptr)->ifa_addr);
                printf("%s: %02x:%02x:%02x:%02x:%02x:%02x\n",
                                    (ifaptr)->ifa_name,
                                    *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5));
            }
        }
        freeifaddrs(ifap);
        return 1;
    } else {
        return 0;
    }
}

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSLog(@"List of Network interfaces:\n");
		listNetworkInterfaces();

		NSLog(@"\n----------------------------------\n");

		NSLog(@"List of interfaces MAC addresses:\n");
		listInterfacesMACs();
	}

	return 0;
}
