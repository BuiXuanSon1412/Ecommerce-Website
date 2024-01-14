package com.ecomm.web.service.impl;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ecomm.web.model.product.Product;
import com.ecomm.web.model.shopping.OrderItem;
import com.ecomm.web.dto.product.AddProductForm;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.model.product.Category;
import com.ecomm.web.model.product.Discount;
import com.ecomm.web.model.product.Inventory;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.CategoryRepository;
import com.ecomm.web.repository.DiscountRepository;
import com.ecomm.web.repository.InventoryRepository;
import com.ecomm.web.repository.OrderItemRepository;
import com.ecomm.web.repository.ProductRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CategoryService;
import com.ecomm.web.service.DiscountService;
import com.ecomm.web.service.ProductService;

import static com.ecomm.web.mapper.ProductMapper.*;

@Service
public class ProductServiceImpl implements ProductService {
    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private CategoryRepository categoryRepository;
    @Autowired
    private InventoryRepository inventoryRepository;
    @Autowired
    private StoreRepository storeRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private CategoryService categoryService;
    @Autowired
    private DiscountRepository discountRepository;
    @Autowired
    private OrderItemRepository orderItemRepository;

    @Override
    public void saveProduct(AddProductForm productForm) {
        Category category = categoryRepository.findById(productForm.getCategory()).get();
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        
        Product product = mapFromAddProductFormToProduct(productForm);
        product.setStore(store);
        product.setCategory(category);
        product.setIsActive(true);
        productRepository.save(product);
        Inventory inventory = Inventory.builder()
                                            .product(product)
                                            .quantity(productForm.getQuantity())
                                            .status(true)
                                            .minimumStock(10)
                                            .build();
        inventoryRepository.save(inventory);
    }
    @Override
    public List<ProductDto> findAllProducts() {
        List<Product> products = productRepository.findAll();
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    @Override
    public ProductDto findProductById(Integer productId) {
        ProductDto product = mapToProductDto(productRepository.findById(productId).get());
        product.setCategory(categoryService.findCategoryByProduct(productId));
        product.setQuantity(inventoryRepository.findQuantityByProduct(productId));
        return product;
    }
    @Override
    public List<ProductDto> findProductByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<Product> products = productRepository.findByStore(store);
        List<ProductDto> productDtos = new ArrayList<>();
        for(Product product : products) {
            if(product == null) return null;
            ProductDto productDto = mapToProductDto(product);
            productDto.setCategory(categoryService.findCategoryByProduct(product.getId()));
            productDto.setQuantity(inventoryRepository.findByProduct(product).getQuantity());
            productDtos.add(productDto);
        }
        return productDtos;
    }
    @Override
    public List<ProductDto> findProductByNameAndCategory(String name, Integer categoryId) {
        List<Product> products = new ArrayList<>();
        name = name.toLowerCase();
        if(name == "" && categoryId != 0) {
            products = productRepository.findByBaseCategory(categoryId);
        }
        else if(name != "" && categoryId == 0) {
            List<Product> subproducts = productRepository.findByName(name);
            for(Product product : subproducts) {
                products.add(product);
            }
        }
        else if(name != "" && categoryId != 0) {
            products = productRepository.findByNameAndCategory(name, categoryId);
        }
        else products = productRepository.findAll();
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    @Override
    public List<ProductDto> findPopolarItems() {
        List<Product> products = productRepository.findPopularItems();
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    
    @Override
    public List<ProductDto> findNewReleases() {
        List<Product> products = productRepository.findNewReleases();
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    @Override
    public boolean pinDiscountToProduct(Integer productId, Integer discountId){
        Product product = productRepository.findById(productId).get();
        Discount discount = discountRepository.findById(discountId).get();
        if(product != null && discount != null) {
            product.setDiscount(discount);
            productRepository.save(product);
            return true;
        }
        return false;
    }
    @Override
    public boolean deleteProduct(Integer productId) {
        if(productId != null) {
            Product product = productRepository.findById(productId).get();
            List<OrderItem> orderItems = orderItemRepository.findByProduct(product);
            if(orderItems.isEmpty()) {
                productRepository.deleteById(productId);
                return true;
            }
        }
        return false;
    }
}    

