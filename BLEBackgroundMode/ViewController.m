//
//  ViewController.m
//  BLEBackgroundMode
//
//  Created by Mario Zhang on 13-12-30.
//  Copyright (c) 2013年 Mario Zhang. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

//#define DEVICE_UUID @"E1D54CF8-C6FA-1873-144C-D4C043F9E27B"
#define TRANSFER_DEVICE_UUID    @"FFF6"
#define TRANSFER_AT_UUID        @"FFF7"
#define TRANSFER_NOTIFY_UUID    @"FFFA"
#define AT_OBD_RT   @"$OBD-RT=" //实时数据流
#define AT_OBD_TT   @"$OBD-TT=" //统计数据流
#define AT_OBD_ST   @"$OBD_ST" //熄火
#define AT_OBD_DTC  @"$OBD-DTC=" //诊断数据
#define AT_OBD_INFO @"$OBD-INFO=" //获取设备信息


@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>
{
    NSMutableArray *foundPeripherals;
    NSString *recvCmd;
}

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *peripheral;
@property (strong, nonatomic) CBService *service;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    foundPeripherals = [NSMutableArray array];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                            queue:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CBCentralManagerDelegate

#pragma mark 检查蓝牙状态
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    DLog();
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self startScanningForUUIDString:TRANSFER_DEVICE_UUID];
    }
}


#pragma mark 开始扫描
- (void) startScanningForUUIDString:(NSString *)uuidString
{
    NSDictionary	*options	= [NSDictionary dictionaryWithObject:@YES forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    [self.centralManager scanForPeripheralsWithServices:nil options:options];
}


#pragma mark 停止扫描
- (void) stopScanning
{
    [self.centralManager stopScan];
}

#pragma mark 发现蓝牙配件
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    [self stopScanning];
    NSLog(@"name:%@ uuid:%@", peripheral.name, peripheral.identifier.UUIDString);
    if (![foundPeripherals containsObject:peripheral]) {
        [foundPeripherals addObject:peripheral];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

#pragma mark 连接蓝牙配件
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    DLog(@"func:%s", __func__);
    self.peripheral = peripheral;
    [self.peripheral setDelegate:self];
    
    // Search only for services that match our UUID
    [self.peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_DEVICE_UUID]]];
}


/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    DLog(@"func:%s", __func__);
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        if ([service.UUID.UUIDString isEqualToString:TRANSFER_DEVICE_UUID]) {
            [self.peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_AT_UUID], [CBUUID UUIDWithString:TRANSFER_NOTIFY_UUID]] forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    _service = service;
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in _service.characteristics) {
        
        NSLog(@"%@", characteristic.UUID.UUIDString);
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_NOTIFY_UUID]]) {
        
            // If it is, subscribe to it
            [_peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    // Once this is complete, we just need to wait for the data to come in.
}

#pragma mark 处理蓝牙发送来的数据  read
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (!error)
    {
        NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        if (!recvCmd) {
            recvCmd = [NSString stringWithString:value];
        } else {
            recvCmd = [recvCmd stringByAppendingString:value];
        }
        if ([value hasSuffix:@"\r\n"]) {
            NSLog(@"收到的一条记录: %@", recvCmd);
            if ([recvCmd hasPrefix:AT_OBD_RT]) { //实时数据流
                NSArray *result = [self paserCMDWithInfo:recvCmd withCmd:AT_OBD_RT];
                NSLog(@"result:%@", result);
            } else if ([recvCmd hasPrefix:AT_OBD_TT]) { //统计数据流
                NSArray *result = [self paserCMDWithInfo:recvCmd withCmd:AT_OBD_TT];
                NSLog(@"result:%@", result);
            } else if ([recvCmd hasPrefix:AT_OBD_ST]) {//熄火
                NSArray *result = [self paserCMDWithInfo:recvCmd withCmd:AT_OBD_ST];
                NSLog(@"result:%@", result);
            } else if ([recvCmd hasPrefix:AT_OBD_DTC]) {//诊断数据
                NSArray *result = [self paserCMDWithInfo:recvCmd withCmd:AT_OBD_DTC];
                NSLog(@"result:%@", result);
            } else if ([recvCmd hasPrefix:AT_OBD_INFO]) {//获取设备信息
                NSArray *result = [self paserCMDWithInfo:recvCmd withCmd:AT_OBD_INFO];
                NSLog(@"result:%@", result);
            }
            
            recvCmd = nil;
        }
    } else {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
    }
}

- (NSArray *)paserCMDWithInfo:(NSString *)info withCmd:(NSString *)cmd
{
    NSString *subStr = [info substringFromIndex:cmd.length];
    NSRange range = [subStr rangeOfString:@"\r\n"];
    subStr = [subStr substringToIndex:range.location];
    NSArray *array = [subStr componentsSeparatedByString:@","];
    return array;
}

#pragma mark 配件断开连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    DLog(@"断开连接:%s", __func__);
    [self.centralManager connectPeripheral:peripheral options:nil];
}

#pragma mark 获取诊断信息
- (IBAction)msgRead:(UIButton *)sender {
    if (self.peripheral.state != CBPeripheralStateConnected) {
        return;
    }
    
    NSString *cmd = nil;
    switch (sender.tag) {
        case 1:
            cmd = @"ATDTC\r\n";
            break;
        case 2:
            cmd = @"ATCDI\r\n";
            break;
        case 3:
            cmd = @"ATI\r\n";
            break;
        default:
            break;
    }
    
    for (CBService *service in self.peripheral.services) {
        for (CBCharacteristic *cha in service.characteristics) {
            if ([cha.UUID.UUIDString isEqualToString:TRANSFER_AT_UUID]) {
                [self.peripheral writeValue:[cmd dataUsingEncoding:NSUTF8StringEncoding]
                          forCharacteristic:cha
                                       type:CBCharacteristicWriteWithResponse];
                break;
            }
        }

    }
    
}

@end   