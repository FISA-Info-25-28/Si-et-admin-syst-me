import { Component, inject } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { UserService } from '../../services/UserService/user-service';
import { User } from '../../models/User/user';


@Component({
  selector: 'app-home',
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive
  ],
  templateUrl: './home.html',
  styleUrl: './home.css',
})
export class Home {
  readonly currentUser: () => User | null;

  constructor(private userService: UserService) {
    this.currentUser = this.userService.currentUser;
    console.log('Current User:', this.currentUser()?.fullName);
  }

  logout() {
    this.userService.logout();
  }
}
