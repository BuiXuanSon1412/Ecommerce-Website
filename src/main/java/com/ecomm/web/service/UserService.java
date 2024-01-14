package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.dto.user.AddressDto;
import com.ecomm.web.dto.user.PaymentDto;
import com.ecomm.web.dto.user.Profile;
import com.ecomm.web.dto.user.UserEntityDto;

public interface UserService {
    void register(UserEntityDto userEntityDto);   
    UserEntityDto findByUsername(String username);
    boolean usernameExists(String username);
    void saveProfile(Profile profile);
    List<AddressDto> findAddressByUser(String username);
    void saveAddress(AddressDto addressDto);
    List<PaymentDto> findPaymentByUser(String username);
    void savePayment(PaymentDto paymentDto);
    boolean deleteAddressById(Integer addressId);
    boolean deletePaymentById(Integer paymentId);
    List<OrderItemDto> findPurchasesByUser(String username);
}
