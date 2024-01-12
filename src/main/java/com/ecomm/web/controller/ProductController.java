package com.ecomm.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.service.ProductService;

@Controller
public class ProductController {
    @Autowired
    private ProductService productService;
    @GetMapping("/product/{productId}")
    public String viewProduct(@PathVariable("productId")Integer productId, Model model) {
        ProductDto product = productService.findProductById(productId);
        model.addAttribute("product", product);
        return "product-view";
    }
    @GetMapping("/product/search")
    public String searchProduct() {
        return "redirect:/home";
    }
}
