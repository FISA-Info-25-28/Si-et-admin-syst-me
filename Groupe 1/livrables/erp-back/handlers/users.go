package handlers

import (
	"github.com/VincentPmf/XanaduERPBack/models"
	"github.com/VincentPmf/XanaduERPBack/database"
	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
)

func HandleCreateUser(c *fiber.Ctx) error {
    var req models.CreateUserRequest
    if err := c.BodyParser(&req); err != nil {
        return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
    }

    if req.Email == "" || req.Password == "" || req.FirstName == "" || req.LastName == "" {
        return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_fields"})
    }

    fullName := req.FirstName + " " + req.LastName

    hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "hash_error"})
    }

    user := models.User{
        Name:     req.FirstName,
        Surname:  req.LastName,
        FullName: fullName,
        Email:    req.Email,
        Password: string(hash),
    }

    result := database.DB.Db.Create(&user)
    if result.Error != nil {
        return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "email_exists"})
    }

    user.Password = ""

    return c.Status(fiber.StatusCreated).JSON(user)
}

func HandleGetUsers(c *fiber.Ctx) error {
    var users []models.User

    result := database.DB.Db.Find(&users)
    if result.Error != nil {
        return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "db_error"})
    }

    for i := range users {
        users[i].Password = ""
    }

    return c.JSON(users)
}



func HandleGetUser(c *fiber.Ctx) error {
    id := c.Params("id")

    var user models.User
    result := database.DB.Db.First(&user, id)
    if result.Error != nil {
        return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "not_found"})
    }

    user.Password = ""

    return c.JSON(user)
}

func HandleLogin(c *fiber.Ctx) error {
    var req models.LoginRequest
    if err := c.BodyParser(&req); err != nil {
        return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_body"})
    }

    if req.Email == "" || req.Password == "" {
        return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "missing_fields"})
    }

    var user models.User
    result := database.DB.Db.Where("email = ?", req.Email).First(&user)
    if result.Error != nil {
        return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
            "success": false,
            "error":   "invalid_credentials",
        })
    }

    // Comparer le mot de passe avec le hash
    err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password))
    if err != nil {
        return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
            "success": false,
            "error":   "invalid_credentials",
        })
    }

    return c.JSON(fiber.Map{
        "success": true,
        "user": fiber.Map{
            "id":       user.ID,
            "email":    user.Email,
            "name":     user.Name,
            "surname":  user.Surname,
            "fullName": user.FullName,
        },
    })
}