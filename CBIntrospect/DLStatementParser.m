//
//  DLStatementParser.m
//
//  Created by Daniel Leber on 7/9/12.
//	Copyright (c) 2012 Daniel Leber
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "DLStatementParser.h"
#import <objc/runtime.h>
#import "CBMacros.h"

// Single character strings
static NSString *const HEX_ADDRESS_PREFIX = @"0x";
static NSString *const OPEN_BRACKET_STRING = @"[";
static NSString *const CLOSE_BRACKET_STRING = @"]";
static NSString *const OPEN_CURLY_BRACE_STRING = @"{";
static NSString *const CLOSE_CURLY_BRACE_STRING = @"}";
static NSString *const COLON_STRING = @":";
static NSString *const SEMI_COLON_STRING = @";";
static NSString *const QUOTATION_STRING = @"\"";
static NSString *const BACKSLASH_STRING = @"\\";
static NSString *const AT_SYMBOL_STRING = @"@";
// BOOL strings
static NSString *const NO_STRING = @"NO";
static NSString *const FALSE_STRING = @"FALSE";
static NSString *const YES_STRING = @"YES";
static NSString *const TRUE_STRING = @"TRUE";
// nil string
static NSString *const NIL_STRING = @"NIL";

// Error strings
NSString * const PSStatementParserErrorUserInfoDescriptionKey = @"PSStatementParserErrorUserInfoDescriptionKey";

@interface DLStatementParser ()
@property (nonatomic, strong) NSCharacterSet *squareBracketInverseCharacterSet;
@property (nonatomic, strong) NSCharacterSet *curlyBraceInverseCharacterSet;
@property (nonatomic, strong) NSCharacterSet *classNameCharacterSet;
@property (nonatomic, strong) NSCharacterSet *hexadecimalCharacterSet;
@property (nonatomic, strong) NSCharacterSet *methodNameCharacterSet;
@property (nonatomic, strong) NSCharacterSet *parameterObjectCharacterSet;
@property (nonatomic, strong) NSCharacterSet *stringCharacterSet;
@property (nonatomic, strong) NSCharacterSet *whitespaceCharacterSet;
@end

@implementation DLStatementParser
@synthesize squareBracketInverseCharacterSet	= _squareBracketInverseCharacterSet;
@synthesize curlyBraceInverseCharacterSet		= _curlyBraceInverseCharacterSet;
@synthesize classNameCharacterSet				= _classNameCharacterSet;
@synthesize hexadecimalCharacterSet				= _hexadecimalCharacterSet;
@synthesize methodNameCharacterSet				= _methodNameCharacterSet;
@synthesize parameterObjectCharacterSet			= _parameterObjectCharacterSet;
@synthesize stringCharacterSet					= _stringCharacterSet;
@synthesize whitespaceCharacterSet				= _whitespaceCharacterSet;

#pragma mark - Lazy loading
- (NSCharacterSet *)squareBracketInverseCharacterSet
{
	if (_squareBracketInverseCharacterSet == nil)
	{
		_squareBracketInverseCharacterSet = CB_Retain([[NSCharacterSet characterSetWithCharactersInString:@"[]"] invertedSet]);
	}
	return _squareBracketInverseCharacterSet;
}
- (NSCharacterSet *)curlyBraceInverseCharacterSet
{
	if (_curlyBraceInverseCharacterSet == nil)
	{
		_curlyBraceInverseCharacterSet = CB_Retain([[NSCharacterSet characterSetWithCharactersInString:@"{}"] invertedSet]);
	}
	return _curlyBraceInverseCharacterSet;
}
- (NSCharacterSet *)classNameCharacterSet
{
	if (_classNameCharacterSet == nil)
	{
		_classNameCharacterSet = CB_Retain([NSCharacterSet alphanumericCharacterSet]);
	}
	return _classNameCharacterSet;
}
- (NSCharacterSet *)hexadecimalCharacterSet
{
	if (_hexadecimalCharacterSet == nil)
	{
		_hexadecimalCharacterSet = CB_Retain([NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"]);
	}
	return _hexadecimalCharacterSet;
}
- (NSCharacterSet *)methodNameCharacterSet
{
	if (_methodNameCharacterSet == nil)
	{
		_methodNameCharacterSet = [self.classNameCharacterSet copy];
	}
	return _methodNameCharacterSet;
}
- (NSCharacterSet *)parameterObjectCharacterSet
{
	if (_parameterObjectCharacterSet == nil)
	{
		NSMutableCharacterSet *parameterObjectCharacterSet = CB_Retain([NSMutableCharacterSet alphanumericCharacterSet]);
		[parameterObjectCharacterSet addCharactersInString:@"."];
		_parameterObjectCharacterSet = parameterObjectCharacterSet;
	}
	return _parameterObjectCharacterSet;
}
- (NSCharacterSet *)stringCharacterSet
{
	if (_stringCharacterSet == nil)
	{
		NSMutableCharacterSet *stringCharacterSet = CB_Retain([NSMutableCharacterSet characterSetWithCharactersInString:@"\"\\"]);
		_stringCharacterSet = stringCharacterSet;
	}
	return _stringCharacterSet;
}
- (NSCharacterSet *)whitespaceCharacterSet
{
	if (_whitespaceCharacterSet == nil)
	{
		_whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	}
	return _whitespaceCharacterSet;
}

#pragma mark - Object lifecycle

+ (DLStatementParser *)sharedParser
{
    static DLStatementParser *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DLStatementParser alloc] init];
    });
    
    return instance;
}

#pragma mark - Private
- (NSRange)rangeOfStatementInString:(NSString *)string
{
	int numberOfBracketsOpen = 0;
	NSRange range = NSMakeRange(NSUIntegerMax, 0);
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	while (scanner.scanLocation < string.length)
	{
		if ([scanner scanString:OPEN_BRACKET_STRING intoString:NULL])
		{
			if (range.location == NSUIntegerMax)
				range.location = scanner.scanLocation;
			
			numberOfBracketsOpen++;
		}
		else if ([scanner scanString:CLOSE_BRACKET_STRING intoString:NULL])
		{
			numberOfBracketsOpen--;
			
			if (numberOfBracketsOpen == 0)
			{
				range.length = scanner.scanLocation;
				break;
			}
		}
		else
		{
			[scanner scanCharactersFromSet:self.squareBracketInverseCharacterSet intoString:NULL];
		}
	}
	
	// The end of the string was reached without closing all of the brackets opened
	if (numberOfBracketsOpen > 0)
	{
		range.location = 0;
		range.length = 0;
	}
	
	return range;
}

- (NSRange)rangeOfStructInString:(NSString *)string
{
	return [self rangeOfStructInString:string numberOfCurlyBracePairs:NULL];
}

- (NSRange)rangeOfStructInString:(NSString *)string numberOfCurlyBracePairs:(NSInteger *)numberOfCurlyBracePairs
{
	NSInteger curlyBracePairs = 0;
	
	int numberOfOpenCurlyBracePairs = 0;
	NSRange range = NSMakeRange(NSUIntegerMax, 0);
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	while (scanner.scanLocation < string.length)
	{
		if ([scanner scanString:OPEN_CURLY_BRACE_STRING intoString:NULL])
		{
			if (range.location == NSUIntegerMax)
				range.location = scanner.scanLocation;
			
			numberOfOpenCurlyBracePairs++;
		}
		else if ([scanner scanString:CLOSE_CURLY_BRACE_STRING intoString:NULL])
		{
			if (numberOfOpenCurlyBracePairs)
				curlyBracePairs++;
			
			numberOfOpenCurlyBracePairs--;
			
			if (numberOfOpenCurlyBracePairs == 0)
			{
				range.length = scanner.scanLocation;
				break;
			}
		}
		else
		{
			[scanner scanCharactersFromSet:self.curlyBraceInverseCharacterSet intoString:NULL];
		} 
	}
	
	// The end of the string was reached without closing all of the curly brackets opened
	if (numberOfOpenCurlyBracePairs > 0)
	{
		range.location = 0;
		range.length = 0;
		curlyBracePairs = 0;
	}
	
	if (numberOfCurlyBracePairs != NULL)
		*numberOfCurlyBracePairs = curlyBracePairs;
	
	return range;
}

- (id)objectForMemoryAddress:(NSString *)memoryAddress
{
	id theObject = nil;
	
	unsigned addr = 0;
	NSScanner *scanner = [[NSScanner alloc] initWithString:memoryAddress];
	[scanner scanHexInt:&addr];
	CB_Release(scanner)
	theObject = (__bridge id)((void*)addr);
	
	return theObject;
}

#pragma mark - Public
- (NSInvocation *)invocationForStatement:(NSString *)statement error:(NSError **)error
{
	// Invocation to create and return
	NSInvocation *invocation = nil;
	NSError *returnError = nil;
	
	// Scan statement
	NSScanner *scanner = CB_AutoRelease([[NSScanner alloc] initWithString:statement]);
	while (scanner.scanLocation < statement.length)
	{
		// Setup
		Class theClass = nil;
		id theObject = nil;
		SEL theSelector = nil;
		
		NSString *tempString = nil;
		
		
		
		// Beginning of Method, open square bracket '['
		if ([scanner scanUpToString:OPEN_BRACKET_STRING intoString:NULL])
		{
			scanner.scanLocation++;
		}
		else if ([scanner scanString:OPEN_BRACKET_STRING intoString:NULL])
		{
			// do nothing...
		}
		else
		{
			NSString *errorString = [NSString stringWithFormat:@"Expected '[' at index: %d, but found: %@", scanner.scanLocation, [statement substringWithRange:NSMakeRange(scanner.scanLocation, 1)]];
			returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
											  code:DLStatementParserErrorStartingOpenBracketNotFound
										  userInfo:[NSDictionary dictionaryWithObject:errorString
																			   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
			CBDebugLog(@"Error! %@", errorString);
			break;
		}
		
		
		
		[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
		tempString = nil;
		
		// Memory address
		if ([scanner scanString:HEX_ADDRESS_PREFIX intoString:NULL])
		{
			NSString *memAddress = nil;
			[scanner scanCharactersFromSet:self.hexadecimalCharacterSet intoString:&memAddress];
			
			theObject = [self objectForMemoryAddress:memAddress];
		}
		// Nested method, open square bracket '['
		else if ([scanner scanString:OPEN_BRACKET_STRING intoString:&tempString])
		{
			// Range of sub statement
			scanner.scanLocation--;
			NSRange subStatementRange = [self rangeOfStatementInString:[statement substringFromIndex:(scanner.scanLocation)]];
			
			// Set scanner location past sub statement
			scanner.scanLocation += subStatementRange.length;
			
			// Sub statement string
			NSString *subStatement = [statement substringWithRange:subStatementRange];
			
			// Parse sub statement
			NSError *objectError = nil;
			NSInvocation *objectInvocation = [self invocationForStatement:subStatement error:&objectError];
			if (objectInvocation)
			{
				[objectInvocation invoke];
				[objectInvocation getReturnValue:&theObject];
			}
			// Error, unable to parse statement
			else
			{
				returnError = objectError;
				break;
			}
		}
		// Class name
		else if ([scanner scanCharactersFromSet:self.classNameCharacterSet intoString:&tempString])
		{
			// Class
			theClass = NSClassFromString(tempString);
			if (theClass)
			{
				tempString = nil;
			}
			// Error, name is not a valid class
			else
			{
				NSString *errorString = [NSString stringWithFormat:@"Invalid class name at index %d: %@", scanner.scanLocation, tempString];
				returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
												  code:DLStatementParserErrorClassNameInvalid
											  userInfo:[NSDictionary dictionaryWithObject:errorString
																				   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
				CBDebugLog(@"Error! %@", errorString);
				break;
			}
		}
		// Error, missing open square bracket
		else
		{
			NSString *errorString = [NSString stringWithFormat:@"Expected class name at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
			returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
											  code:DLStatementParserErrorClassNameNotFound
										  userInfo:[NSDictionary dictionaryWithObject:errorString
																			   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
			CBDebugLog(@"Error! %@", errorString);
			break;
		}
		
		// Method name setup
		NSMutableString *selectorName = CB_AutoRelease([[NSMutableString alloc] initWithCapacity:statement.length - scanner.scanLocation]);
		int numberOfMethodParameters = 0; // Used for parsing parameter objects
		
		NSUInteger methodNameScanLocation = scanner.scanLocation;
		BOOL isParsingMethodName = YES; // Set to NO when done
		
		// Parse method name
		while (isParsingMethodName && scanner.scanLocation < statement.length)
		{
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			tempString = nil;
			
			// Method name
			if ([scanner scanCharactersFromSet:self.methodNameCharacterSet intoString:&tempString])
			{
				[selectorName appendString:tempString];
				
				[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
				tempString = nil;
				
				// Parameter separator ':'
				if ([scanner scanString:COLON_STRING intoString:&tempString])
				{
					numberOfMethodParameters++;
					
					[selectorName appendString:tempString];
					
					[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
					tempString = nil;
					
					// Parameter object name
					if ([scanner scanString:AT_SYMBOL_STRING intoString:NULL])
					{
						BOOL numberOfNonEscapedQuotations = 0;
						while (numberOfNonEscapedQuotations < 2)
						{
							[scanner scanUpToString:QUOTATION_STRING intoString:NULL];
							[scanner scanString:QUOTATION_STRING intoString:NULL];
							
							NSString *quotationPreviousCharacter = [statement substringWithRange:NSMakeRange(scanner.scanLocation - 2, 1)];
							// TODO: Ensure this backslash '\' isn't backslash escaped already
							if ([quotationPreviousCharacter isEqualToString:BACKSLASH_STRING] == NO)
							{
								numberOfNonEscapedQuotations++;
							}
						}
					}
					else if ([scanner scanCharactersFromSet:self.parameterObjectCharacterSet intoString:NULL])
					{
						// Do nothing...
					}
					// Parameter is struct
					else if ([scanner scanString:OPEN_CURLY_BRACE_STRING intoString:&tempString])
					{
						// Scan past command
						scanner.scanLocation--;
						scanner.scanLocation += [self rangeOfStructInString:[statement substringFromIndex:(scanner.scanLocation)]].length;
					}
					// Parameter is command
					else if ([scanner scanString:OPEN_BRACKET_STRING intoString:&tempString])
					{
						// Scan past command
						scanner.scanLocation--;
						scanner.scanLocation += [self rangeOfStatementInString:[statement substringFromIndex:(scanner.scanLocation)]].length;
					}
					// Error, no valid parameter
					else
					{
						NSString *errorString = [NSString stringWithFormat:@"Selector parameter #%d missing at statement index %d", numberOfMethodParameters, scanner.scanLocation];
						returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
														  code:DLStatementParserErrorParameterNotFound
													  userInfo:[NSDictionary dictionaryWithObject:errorString
																						   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
						CBDebugLog(@"Error! %@", errorString);
						break;
					}
				}
			}
			// Error, no method name
			else
			{
				NSString *errorString = [NSString stringWithFormat:@"Expected method name at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
				returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
												  code:DLStatementParserErrorMethodNameNotFound
											  userInfo:[NSDictionary dictionaryWithObject:errorString
																				   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
				CBDebugLog(@"Error! %@", errorString);
				break;
			}
			
			// End of method, closing square bracket ']'
			if ([scanner scanString:CLOSE_BRACKET_STRING intoString:NULL])
			{
				scanner.scanLocation--;
				isParsingMethodName = NO;
			}
		}
		
		// Error while parsing method name
		if (isParsingMethodName)
			break;
		
		// Method selector
		theSelector = NSSelectorFromString(selectorName);
		selectorName = nil;
		
		// Create invocation from class
		if (theClass)
		{
			// Error, class doesn't respond to selector
			if ([theClass respondsToSelector:theSelector] == NO)
			{
				NSString *errorString = [NSString stringWithFormat:@"Class '%@' doesn't respond to selector: %@", NSStringFromClass(theClass), NSStringFromSelector(theSelector)];
				returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
												  code:	DLStatementParserErrorClassDoesNotRespondToSelector
											  userInfo:[NSDictionary dictionaryWithObject:errorString
																				   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
				CBDebugLog(@"Error! %@", errorString);
				break;
			}
			
			NSMethodSignature *methodSignature = [theClass methodSignatureForSelector:theSelector];
			invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
			invocation.target = theClass;
			invocation.selector = theSelector;
		}
		// Create invocation from object
		else if (theObject)
		{
			// Error, object doesn't respond to selector
			if ([theObject respondsToSelector:theSelector] == NO)
			{
				NSString *errorString = [NSString stringWithFormat:@"Instance of '%@' doesn't respond to selector: %@", NSStringFromClass([theObject class]), NSStringFromSelector(theSelector)];
				returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
												  code:	DLStatementParserErrorInstanceDoesNotRespondToSelector
											  userInfo:[NSDictionary dictionaryWithObject:errorString
																				   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
				CBDebugLog(@"Error! %@", errorString);
				break;
			}
			
			NSMethodSignature *methodSignature = [theObject methodSignatureForSelector:theSelector]; 
			invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
			invocation.target = theObject;
			invocation.selector = theSelector;
		}
		// Error, no class or object
		else
		{
			CBDebugLog(@"Error! Unable to create invocation!");
			break;
		}
		
		
		
		// Method parameters
		if (numberOfMethodParameters)
		{
			scanner.scanLocation = methodNameScanLocation;
		}
		
		// Iterate through selector parameters
		for (int index = 2; (index - 2) < numberOfMethodParameters; index++)
		{
			// Method name, ignore
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			[scanner scanCharactersFromSet:self.methodNameCharacterSet intoString:NULL];
			
			// Parameter separator ':', ignore
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			[scanner scanString:COLON_STRING intoString:NULL];
			
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			tempString = nil;
			
			// Parameter
			// String
			if ([scanner scanString:AT_SYMBOL_STRING intoString:NULL])
			{
				[scanner scanString:QUOTATION_STRING intoString:NULL];
				
				// TODO: Implement supporting backslash '\' encoded characters
				NSMutableString *stringContents = [[NSMutableString alloc] initWithCapacity:(statement.length - scanner.scanLocation)];
				BOOL isScanningParameterString = YES;
				while (isScanningParameterString && scanner.scanLocation < statement.length)
				{
					tempString = nil;
					[scanner scanUpToString:QUOTATION_STRING intoString:&tempString];
					[stringContents appendString:tempString];
					
					NSString *quotationPreviousCharacter = [statement substringWithRange:NSMakeRange(scanner.scanLocation - 2, 1)];
					// TODO: Ensure this backslash '\' isn't backslash escaped already
					if ([quotationPreviousCharacter isEqualToString:BACKSLASH_STRING])
					{
						tempString = nil;
						[scanner scanString:QUOTATION_STRING intoString:&tempString];
						[stringContents appendString:tempString];
					}
					else
					{
						[scanner scanString:QUOTATION_STRING intoString:NULL];
						isScanningParameterString = NO;
					}
				}
				
				NSString *argument = CB_AutoRelease([[NSString alloc] initWithString:stringContents]);
                CB_Release(stringContents)
				
				[invocation setArgument:&argument atIndex:index];
			}
			// Primitive? type
			else if ([scanner scanCharactersFromSet:self.parameterObjectCharacterSet intoString:&tempString])
			{
				// Note: referenced from <objc/runtime.h>, starting at line 362
				const char *parameterType = nil;
				void *parameterValue = nil;
				
				NSString *compareString = [tempString uppercaseString];
				if ([compareString isEqualToString:NO_STRING] ||
					[compareString isEqualToString:FALSE_STRING])
				{
					parameterType = [[NSString stringWithFormat:@"%c", _C_BOOL] UTF8String];
				}
				else if ([compareString isEqualToString:YES_STRING] ||
						 [compareString isEqualToString:TRUE_STRING])
				{
					parameterType = [[NSString stringWithFormat:@"%c", _C_BOOL] UTF8String];
                    NSNumber *num = CB_AutoRelease([[NSNumber alloc] initWithBool:YES])
					parameterValue = [num pointerValue];
				}
				else if ([compareString isEqualToString:NIL_STRING])
				{
                    NSString *str = [[NSString alloc] initWithFormat:@"%c", _C_VOID];
                    CB_NO_ARC([str autorelease])
					parameterType = [str UTF8String];
				}
				else
				{
					NSNumberFormatter *numberFormatter = CB_AutoRelease([[NSNumberFormatter alloc] init]);
					NSNumber *stringNumber = [numberFormatter numberFromString:tempString];
					
					if (stringNumber)
					{
						parameterType = [stringNumber objCType];
						[stringNumber getValue:&parameterValue];
					}
				}
				
				if (parameterType == nil)
				{
					NSString *errorString = [NSString stringWithFormat:@"Unknown parameter at index %d: %@", (index - 2), tempString];
					returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
													  code:DLStatementParserErrorParameterTypeUnknown
												  userInfo:[NSDictionary dictionaryWithObject:errorString
																					   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
					CBDebugLog(@"Error! %@", errorString);
					break;
				}
				
				[invocation setArgument:&parameterValue atIndex:index];
			}
			// Struct
			else if ([scanner scanString:OPEN_CURLY_BRACE_STRING intoString:&tempString])
			{
				NSInteger numberOfCurlyBracePairs = 0;
				
				// Range of sub statement
				scanner.scanLocation--;
				NSRange subStatementRange = [self rangeOfStructInString:[statement substringFromIndex:(scanner.scanLocation)] numberOfCurlyBracePairs:&numberOfCurlyBracePairs];
				subStatementRange.location = scanner.scanLocation;
				
				// Set scanner location past sub statement
				scanner.scanLocation += subStatementRange.length;
				
				// Sub statement string
				NSString *subStatement = [statement substringWithRange:subStatementRange];
				
//				NSInteger numberOfOpenCurlyBrackes = 0;
//				NSString *temp = [subStatement copy];
//				while (temp.length)
//				{
//					NSRange range = [temp rangeOfString:OPEN_CURLY_BRACE_STRING];
//					if (range.length)
//					{
//						numberOfOpenCurlyBrackes++;
//						temp = [temp substringFromIndex:range.location];
//					}
//					else
//					{
//						break;
//					}
//				}
				
				switch (numberOfCurlyBracePairs)
				{
					case 1:
					{
						CGPoint point = CGPointFromString(subStatement);
						[invocation setArgument:&point atIndex:index];
						break;
					}
					case 3:
					{
						CGRect rect = CGRectFromString(subStatement);
						[invocation setArgument:&rect atIndex:index];
						break;
					}
						
					default:
					{
						NSString *errorString = [NSString stringWithFormat:@"Struct '%@' does not conform to a CGPoint/CGSize or CGRect", subStatement];
						returnError = [NSError errorWithDomain:@"com.thedanielleber.DLStamementParser" 
														  code:DLStatementParserErrorParameterIsInvalidStruct
													  userInfo:[NSDictionary dictionaryWithObject:errorString
																						   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
						CBDebugLog(@"Error! %@", errorString);
						break;
					}
				}
			}
			// Command
			else if ([scanner scanString:OPEN_BRACKET_STRING intoString:&tempString])
			{
				// Range of sub statement
				scanner.scanLocation--;
				NSRange subStatementRange = [self rangeOfStatementInString:[statement substringFromIndex:(scanner.scanLocation)]];
				subStatementRange.location = scanner.scanLocation;
				
				// Set scanner location past sub statement
				scanner.scanLocation += subStatementRange.length;
				
				// Sub statement string
				NSString *subStatement = [statement substringWithRange:subStatementRange];
				
				NSError *parameterError = nil;
				NSInvocation *parameterInvocation = [self invocationForStatement:subStatement error:&parameterError];
				if (parameterInvocation)
				{
					[parameterInvocation invoke];
					
					void *parameterReturnValue = nil;
					[parameterInvocation getReturnValue:&parameterReturnValue];
					
					const char *parameterReturnType = [[parameterInvocation methodSignature] methodReturnType];
					const char *theInvocationArgumentType = [[invocation methodSignature] getArgumentTypeAtIndex:index];
					if (strncmp(parameterReturnType, theInvocationArgumentType, 1) == 0)
					{
						
						[invocation setArgument:&parameterReturnValue atIndex:index];
					}
					else
					{
						// TODO: look into converting return type into argument type
						NSString *errorString = [NSString stringWithFormat:@"Selector parameter %d command at statement index %d return type '%c' different from selector argument type '%c'. Command: %@", index, scanner.scanLocation, (int)[NSString stringWithUTF8String:parameterReturnType], (int)[NSString stringWithUTF8String:theInvocationArgumentType], subStatement];
						returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
														  code:DLStatementParserErrorParameterReturnValueDifferentFromSelectorArgumentValue
													  userInfo:[NSDictionary dictionaryWithObject:errorString
																						   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
						CBDebugLog(@"Error! %@", errorString);
						break;
					}
				}
				else
				{
					returnError = parameterError;
					break;
				}
			}
			// Error, no valid parameter
			else
			{
				NSString *errorString = [NSString stringWithFormat:@"Expected method name at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
				returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
												  code:DLStatementParserErrorMethodNameNotFound
											  userInfo:[NSDictionary dictionaryWithObject:errorString
																				   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
				CBDebugLog(@"Error! %@", errorString);
				break;
			}
		}
		
		// Error parsing parameters
		if (numberOfMethodParameters == NSUIntegerMax || returnError)
			break;
		
		
		
		// End of command, close square bracket ']'
		if ([scanner scanString:CLOSE_BRACKET_STRING intoString:NULL] == NO)
		{
			NSString *errorString = [NSString stringWithFormat:@"Expected ']' at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
			returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
											  code:DLStatementParserErrorClosingCloseBracketNotFound
										  userInfo:[NSDictionary dictionaryWithObject:errorString
																			   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
			CBDebugLog(@"Error! %@", errorString);
			break;
		}
		
		if (returnError)
			break;
		
		
		
		[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
		
		// TODO: implement parsing multiple commands
		if ([scanner scanString:SEMI_COLON_STRING intoString:NULL])
		{
		}
		
		
		
		// Finish scanning through remainder of statement
		[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
	}

	// Error
	if (returnError)
	{
		// Don't return the invocation if there was an error
		invocation = nil;
		
		// Set error pointer
		if (error != NULL)
		{
			*error = returnError;
		}
	}
	else if (invocation == nil && error != NULL)
	{
		NSString *errorString = [NSString stringWithFormat:@"Unknown error occured parsing: %@", statement];
		returnError = [NSError errorWithDomain:@"com.DLStamementParser" 
										  code:DLStatementParserErrorUnknown
									  userInfo:[NSDictionary dictionaryWithObject:errorString
																		   forKey:PSStatementParserErrorUserInfoDescriptionKey]];
		CBDebugLog(@"Error! %@", errorString);
		
		*error = returnError;
	}
	// Return status of parsing statement
	return invocation;
}

@end