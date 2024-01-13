package com.ecomm.web.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.product.DiscountDto;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.model.product.Discount;
import com.ecomm.web.model.product.Product;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.DiscountRepository;
import com.ecomm.web.repository.ProductRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.DiscountService;

import static com.ecomm.web.mapper.DiscountMapper.mapToDiscountDto;
import static com.ecomm.web.mapper.DiscountMapper.mapToDiscount;
@Service
public class DiscountServiceImpl implements DiscountService{
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private StoreRepository storeRepository;
    @Autowired
    private DiscountRepository discountRepository;
    @Autowired
    private ProductRepository productRepository;
    @Override
    public List<DiscountDto> findAllDiscountByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<Discount> dicounts = discountRepository.findByStore(store);
        return dicounts.stream().map((discount) -> mapToDiscountDto(discount)).collect(Collectors.toList());
    }
    
    @Override
    public List<DiscountDto> findActiveDiscountsByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<Discount> dicounts = discountRepository.findActiveDiscountsByStore(store.getId());
        return dicounts.stream().map((discount) -> mapToDiscountDto(discount)).collect(Collectors.toList());
    }
    
    
    @Override
    public void saveDiscount(DiscountDto discountDto) {
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        Discount discount = mapToDiscount(discountDto);
        discount.setStore(store);
        discountRepository.save(discount);
    }
    @Override
    public Double productDiscount(ProductDto productDto) {
        Product product = productRepository.findById(productDto.getId()).get();
        if(product.getDiscount() == null) return (double)0;
        return product.getDiscount().getDisc();
    }
}

