package com.ecomm.web.controller.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.service.StoreService;

@RestController
public class StoreRestController {
    @Autowired
    StoreService storeService;
    @PostMapping("/store/deliver")
    public String updateBusiness(@RequestParam(name = "business") Boolean business){
        
        return "Changed successfully";
    }
}
