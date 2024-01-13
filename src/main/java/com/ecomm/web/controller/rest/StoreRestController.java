package com.ecomm.web.controller.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.ProductService;
import com.ecomm.web.service.StoreService;

@RestController
public class StoreRestController {
    @Autowired
    private StoreService storeService;
    @Autowired
    private ProductService productService;
    @PostMapping("/store/delivery")
    public String updateBusiness(@RequestParam(name = "method") String methodName){
        String username = SecurityUtil.getSessionUser();
        boolean status = storeService.updateMethod(methodName, username);
        if(status) return "Changed successfully";
        return "Changed unsuccessfully";
    }

    @PostMapping("/discount/pin")
    public String pinDiscount(@RequestParam(name = "pid") Integer productId, @RequestParam(name = "did") Integer discountId) {
        boolean status = productService.pinDiscountToProduct(productId, discountId);
        if(status) return "successfully";
        return "unsuccessfully";
    }
    
}
