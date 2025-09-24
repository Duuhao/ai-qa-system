package com.ai.qa.user.application;

import com.ai.qa.user.api.dto.*;
import com.ai.qa.user.domain.entity.User;

public interface UserService {
    
    /**
     * 用户注册
     * @param request 注册请求
     * @return 用户信息
     */
    UserInfoResponse register(UserRegisterRequest request);
    
    /**
     * 用户登录
     * @param request 登录请求
     * @return 登录响应（包含token和用户信息）
     */
    LoginResponse login(UserLoginRequest request);
    
    /**
     * 修改密码
     * @param userId 用户ID
     * @param request 修改密码请求
     * @return 是否成功
     */
    boolean changePassword(Long userId, ChangePasswordRequest request);
    
    /**
     * 修改昵称
     * @param userId 用户ID
     * @param request 修改昵称请求
     * @return 用户信息
     */
    UserInfoResponse updateNickname(Long userId, UpdateNicknameRequest request);
    
    /**
     * 根据用户ID获取用户信息
     * @param userId 用户ID
     * @return 用户信息
     */
    UserInfoResponse getUserInfo(Long userId);
    
    /**
     * 根据用户名获取用户信息
     * @param username 用户名
     * @return 用户信息
     */
    UserInfoResponse getUserInfoByUsername(String username);
}
