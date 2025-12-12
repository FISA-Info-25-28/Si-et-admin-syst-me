package main

import (
	"github.com/gofiber/fiber/v2"
	"github.com/VincentPmf/XanaduERPBack/handlers"
)


func setupRoutes(app *fiber.App) {
	app.Get("/users", handlers.HandleGetUsers)
	app.Get("/users/:id", handlers.HandleGetUser)
	app.Post("/users", handlers.HandleCreateUser)
	app.Post("/login", handlers.HandleLogin)
}

