package com.ecomm.web.controller.rest;

import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;

import com.ecomm.web.service.UserService;

@RestController
public class UserRestController {
    @Autowired
    private UserService userService;
    
}
