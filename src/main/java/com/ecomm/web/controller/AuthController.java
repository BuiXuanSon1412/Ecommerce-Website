package com.ecomm.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

import com.ecomm.web.dto.user.UserEntityDto;
import com.ecomm.web.service.UserService;

import jakarta.validation.Valid;

@Controller
public class AuthController {
    @Autowired
    private UserService userService;
    
    @GetMapping("/login")
    public String loginPage() {
        return "login";
    }
    @GetMapping("/register")
    public String registerForm(Model model) {
        UserEntityDto user = UserEntityDto.builder().build();
        model.addAttribute("user", user);
        return "register";
    }
    @PostMapping("/register")
    public String register(@Valid @ModelAttribute("user") UserEntityDto user, BindingResult result, Model model) {           
        if(result.hasErrors()) {
            model.addAttribute("user", user);
            return "register";
        }             
        if(userService.usernameExists(user.getUsername())) {
            return "redirect:/register?fail";
        }
        userService.register(user);
        return "redirect:/login?regSuccess";        
    }
}
