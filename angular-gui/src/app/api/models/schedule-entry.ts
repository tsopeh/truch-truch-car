import { Station } from './station'
import { Train } from './train'

export type ScheduleEntryId = string & { __SCHEDULE_ENTRY_ID__: undefined }

export enum ScheduleEntryState {
  Planned = 'Planned',
  InTransit = 'InTransit',
  Complete = 'Complete',
  Canceled = 'Canceled'
}

export interface ScheduleEntryBrief {
  id: ScheduleEntryId
  state: ScheduleEntryState
  train: Train
  notice: string | null
  departureDateTime: string
  arrivalDateTime: string
  latency: number | null
}

export interface ScheduleEntryFull {
  id: ScheduleEntryId
  state: ScheduleEntryState
  train: Train
  notice: string | null
  stations: ReadonlyArray<Station>
  latency: number | null
}