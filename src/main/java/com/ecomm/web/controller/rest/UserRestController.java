package com.ecomm.web.controller.rest;

import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.PostMapping;

import com.ecomm.web.dto.user.Profile;
import com.ecomm.web.dto.user.UserEntityDto;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.UserService;

import org.springframework.ui.Model;
import jakarta.validation.Valid;

@RestController
public class UserRestController {
    @Autowired
    private UserService userService;
    
}
