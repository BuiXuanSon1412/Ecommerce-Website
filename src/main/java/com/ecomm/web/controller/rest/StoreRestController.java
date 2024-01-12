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
    @PostMapping("/store/business")
    public String updateBusiness(@RequestParam(name = "business") Boolean business){
        
        return "Changed successfully";
    }
    @PostMapping("/store/fast")
    public String updateFast(@RequestParam(name = "fast") Boolean fast){
        
        return "Changed successfully";
    }
    @PostMapping("/store/express")
    public String updateExpress(@RequestParam(name = "express") Boolean express){
        
        return "Changed successfully";
    }
}
