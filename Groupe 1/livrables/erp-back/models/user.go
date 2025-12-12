package models

import "gorm.io/gorm"

type User struct {
	gorm.Model
	Name  string `json:"name" gorm:"type:text;not null"`
	Surname string `json:"username" gorm:"type:text;default:null"`
	FullName string `json:"fullname" gorm:"type:text;default:null"`
	Email string `json:"email" gorm:"type:text;not null"`
	Password string `json:"password" gorm:"type:text;not null"`
}


type CreateUserRequest struct {
    Email     string `json:"email"`
    Password  string `json:"password"`
    FirstName string `json:"firstName"`
    LastName  string `json:"lastName"`
}

type LoginRequest struct {
    Email    string `json:"email"`
    Password string `json:"password"`
}

type UpdateUserRequest struct {
    Email     *string `json:"email"`
    Password  *string `json:"password"`
    FirstName *string `json:"firstName"`
    LastName  *string `json:"lastName"`
}