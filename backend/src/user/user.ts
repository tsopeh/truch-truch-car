export enum Gender {
  Male = 'male',
  Female = 'female',
  Other = 'other',
}

export interface User {
  id: string
  password: string
  firstName: string
  lastName: string
  gender: Gender
  dateOfBirth: string
  email: string
  phone: string
  driver: Array<string>
  passenger: Array<string>
  avatar: string
  accountCreationDate: string
}

export interface PreviewUser {
  id: string
  firstName: string
  lastName: string
  avatar: string
  wasDriverCount: number
  wasPassengerCount: number
  memberFromDate: string
}

export interface SignUpUser {
  password: string
  firstName: string
  lastName: string
  gender: Gender
  dateOfBirth: string
  email: string
  phone: string
}

export interface LoginParams {
  email: string
  password: string
}

export interface RegisterParams {
  email: string
  password: string
  firstName: string
  lastName: string
  gender: Gender
  dateOfBirth: string
  phone: string
}

export interface LoggedInUser {
  id: string
  firstName: string
  lastName: string
  gender: Gender
  dateOfBirth: string
  email: string
  phone: string
  avatar: string
}

export function userToLoggedInUser (user: User): LoggedInUser {
  return {
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    gender: user.gender,
    dateOfBirth: user.dateOfBirth,
    email: user.email,
    phone: user.phone,
    avatar: user.avatar
  }
}
