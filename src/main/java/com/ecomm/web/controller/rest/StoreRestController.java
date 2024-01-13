package com.ecomm.web.controller.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.StoreService;

@RestController
public class StoreRestController {
    @Autowired
    StoreService storeService;
    
    @PostMapping("/store/delivery")
    public String updateBusiness(@RequestParam(name = "method") String methodName){
        String username = SecurityUtil.getSessionUser();
        boolean status = storeService.updateMethod(methodName, username);
        if(status) return "Changed successfully";
        return "Changed unsuccessfully";
    }
    
}
