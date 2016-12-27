//
//  Package.swift
//  CHAmazonProductAdvertisingAPI
//

import PackageDescription

let package = Package(
	name: "CHAmazonProductAdvertisingAPI",
	targets: [],
	dependencies: [
        .Package(url: "https://github.com/PerfectlySoft/Perfect-libxml2.git", majorVersion: 2, minor: 0)
        .Package(url: "https://github.com/PerfectlySoft/Perfect-XML.git", majorVersion: 2, minor: 0),
    ],
	exclude: []
)
