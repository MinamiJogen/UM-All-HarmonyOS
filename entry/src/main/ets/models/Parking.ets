export const CAR_PARK_FILTER_ALL: string = 'All';
export const CAR_PARK_TARGET_STAFF: string = 'Staff';
export const CAR_PARK_TARGET_MONTHLY_PASS: string = 'Monthly Pass';
export const CAR_PARK_TARGET_VISITOR: string = 'Visitor';
export const CAR_PARK_VEHICLE_LIGHT: string = 'Light Vehicle';
export const CAR_PARK_VEHICLE_MOTORCYCLE: string = 'Motorcycle';

export interface CarParkRecord {
  parkingType: string;
  vehicleType: string;
  noOfAvailableSpace: number;
}

export interface CarParkAvailabilityItem {
  carParkCode: string;
  recordDate: string;
  records: CarParkRecord[];
}

export interface CarParkPlaceInfo {
  code: string;
  descriptionZh: string;
  descriptionEn?: string;
}
