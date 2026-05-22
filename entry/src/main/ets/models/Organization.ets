export interface UmOrgSubUnit {
  subUnitCode: string;
  subUnitName: string;
  chinSubUnitName: string;
  portSubUnitName?: string;
}

export interface UmOrgUnit {
  unitCode: string;
  unitName: string;
  chinUnitName: string;
  portUnitName?: string;
  subUnit?: UmOrgSubUnit[];
}
