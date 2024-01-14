package com.ecomm.web.controller.rest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ecomm.web.service.ProductService;

@RestController
public class ProductRestController {
    @Autowired
    private ProductService productService;
    @PostMapping("/product/delete")
    public String deleteProduct(@RequestParam(name = "pid") Integer productId) {
        boolean status = productService.deleteProduct(productId);
        if(status) return "delete successfully";
        return "Still exist related orders";
    }
}
