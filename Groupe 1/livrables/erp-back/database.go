package database

import (
	"log"

	"github.com/VincentPmf/XanaduERPBack/models"
	"golang.org/x/crypto/bcrypt"
    "github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type Dbinstance struct {
	Db *gorm.DB
}

var DB Dbinstance

func ConnectDb() {
    db, err := gorm.Open(sqlite.Open("xanadu.db"), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
    })

    if err != nil {
        log.Fatal("Failed to connect to database. \n", err)
    }

	log.Println("connected")
	db.Logger = logger.Default.LogMode(logger.Info)

	log.Println("running migrations")
	db.AutoMigrate(&models.User{})

	DB = Dbinstance{
		Db: db,
	}

	seedUsers(db)
}

func seedUsers(db *gorm.DB) {
    users := []struct {
        FirstName string
        LastName  string
        Email     string
        Password  string
    }{
        {"Vincent", "CAUSSE", "vincent.causse@xanadu.com", "Xanadu2025!"},
        {"Youcef", "AFANE", "youcef.afane@xanadu.com", "Xanadu2025!"},
    }

    for _, u := range users {
        var existing models.User
        result := db.Where("email = ?", u.Email).First(&existing)
        if result.Error == nil {
            log.Printf("User %s already exists, skipping\n", u.Email)
            continue
        }

        hash, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
        if err != nil {
            log.Printf("Error hashing password for %s: %v\n", u.Email, err)
            continue
        }

        user := models.User{
            Name:     u.FirstName,
            Surname:  u.LastName,
            FullName: u.FirstName + " " + u.LastName,
            Email:    u.Email,
            Password: string(hash),
        }

        if err := db.Create(&user).Error; err != nil {
            log.Printf("Error creating user %s: %v\n", u.Email, err)
        } else {
            log.Printf("Created user: %s\n", u.Email)
        }
    }
}