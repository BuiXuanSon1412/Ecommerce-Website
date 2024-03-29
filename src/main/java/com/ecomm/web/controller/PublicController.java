package com.ecomm.web.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

import com.ecomm.web.dto.product.CategoryDto;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.service.CategoryService;
import com.ecomm.web.service.ProductService;

@Controller
public class PublicController {
    @Autowired
    private ProductService productService;
    @Autowired
    private CategoryService categoryService;

    @GetMapping("/home")
    public String displayHome(Model model) {
        List<ProductDto> products = productService.findAllProducts();
        List<CategoryDto> categories = categoryService.findAllBaseCategories();
        model.addAttribute("categories", categories);
        model.addAttribute("products", products);
        return "home";
    }

    @GetMapping("/search/product")
    public String searchProduct(@RequestParam(value = "name", required = false) String name,
            @RequestParam(value = "categoryId", required = false) Integer categoryId, Model model) {
        if(name == "" && categoryId == 0) return "redirect:/home";
        List<ProductDto> products = productService.findProductByNameAndCategory(name, categoryId);
        List<CategoryDto> categories = categoryService.findAllBaseCategories();
        model.addAttribute("categories", categories);
        model.addAttribute("products", products);
        return "home";
    }
    @GetMapping("/newreleases")
    public String newReleases(Model model) {
        List<ProductDto> products = productService.findNewReleases();
        List<CategoryDto> categories = categoryService.findAllBaseCategories();
        model.addAttribute("categories", categories);
        model.addAttribute("products", products);
        return "home";
    }
    @GetMapping("/popularitems")
    public String popularItems(Model model) {
        //List<ProductDto> products = productService.findPopolarItems();
        List<CategoryDto> categories = categoryService.findAllBaseCategories();
        model.addAttribute("categories", categories);
        //model.addAttribute("products", products);
        return "home";
    }
}
